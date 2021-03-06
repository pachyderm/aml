# Pachyderm-AzureML integration: Private Preview Instructions

**Please note: This repo should only be used by Pachyderm-approved private preview users. Please contact [joey@pachyderm.io](mailto:joey@pachyderm.io) to become a private preview user. This is a preview, do not use it for production!**

## Architecture

![Pachyderm and Azure Machine Learning architecture diagram](pachyderm-aml.png)

## Requirements

How to set up AML with Pachyderm:

* You need to be running Linux/MacOS/WSL on your local machine
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) 1.0+

## Step 0 - Enable custom datastores on your Azure subscription ID

Email [moira.chambers@pachyderm.io](mailto:moira.chambers@pachyderm.io) with your Azure Subscription ID and we'll arrange for custom datastores to be enabled on your account. This allows the rest of the instructions to work.

## Step 1 - Deploy stack

Clone this repo.

```
git clone https://github.com/pachyderm/aml
```

```
cd aml
```

Log into Azure:

```
az login
```

Choose the Azure region where you want to deploy all resources:

```
export TF_VAR_location="East US"
```

> Note: if you're deploying with an existing AzureML workspace, the location above should match where your workspace is.

Optionally, specify the type of data you want to store.

[`FileDataset`](https://docs.microsoft.com/en-us/python/api/azureml-core/azureml.data.filedataset?view=azure-ml-py): matches all `files`, for unstructured data OR

[`TabularDataset`](https://docs.microsoft.com/en-us/python/api/azureml-core/azureml.data.tabulardataset?view=azure-ml-py):
- JSON Lines format (`jsonl`, matches `*.jsonl` and aggregates into a single table, in which case all json lines files in a given Pachyderm repo must have compatible schemas)
- CSV format (`delmited`, matches `*.csv` and aggregates into a single table - in which case all csv files in a given Pachyderm repo must have compatible schemas)

For example:

```
export TF_VAR_pachyderm_syncer_mode="files" # or "jsonl" or "delimited"
```

Now we'll deploy a Kubernetes cluster, install Pachyderm on it, then start the Syncer VM.

### Option 1: Automatically create a new AzureML workspace and resource group:

```
bash scripts/setup.sh
```

> Note: if you get errors about exceeding quota, try a different region by configuring `TF_VAR_location`

### Option 2: Integrate Pachyderm with an existing AzureML workspace:

If you're attaching AzureML-Pachyderm to an existing AzureML workspace, specify the resource group that the target AzureML workspace is in here, as well as specifying the workspace name:

```
export TF_VAR_existing_resource_group_name="existing-resource-group"
export TF_VAR_existing_workspace_name="existing-workspace"
bash scripts/setup.sh
```

(You can also create a new AzureML workspace in an existing resource group by only specifying `TF_VAR_existing_resource_group_name` but not `TF_VAR_existing_workspace_name`.)

### Option 3: Only create a new Syncer VM, and integrate exiting Azure ML workspace with existing Pachyderm cluster

We will only create a new VM for the Syncer, and adopt existing Pachyderm and AML infrastructure. You will need to copy the Terraform code to a fresh new directory.

```
mkdir syncer1  # recommend naming this as syncer-$workspace_name
cp terraform/*.tf syncer1
cp -R terraform/out/ syncer1/out  # copy kubeconfig, env.sh and helmvalues, which setup.sh depends on
```

Setup appropriate environment variables.

```
export TERRAFORM_WD=syncer1
export TF_VAR_skip_pachyderm_deploy=1
export TF_VAR_existing_resource_group_name="existing-resource-group"
export TF_VAR_existing_workspace_name="existing-workspace"
```

Run the setup script and wait for the Syncer VM to come online.

```
bash scripts/setup.sh
```

> Note: the Syncer VM is based on a Marketplace VM image built using packer. For more info go to [VM image docs](packer/README.md)

### How to connect to the Syncer VM

The default username on the Syncer VM is `pachyderm`. This is useful for debugging and quickly fixing issues that might appear in the Syncer. You can also use the syncer's builtin `pachctl` to operate Pachyderm.

```
# From the root aml repo directory
ssh pachyderm@$(cd terraform; terraform output -raw instance_ip)
```

## Step 2 - Update rslex on your AML Compute

Install a custom built version of the `azureml-dataprep-rslex` library.

> Note: this step will no longer be necessary after Microsoft releases an official library with the Pachyderm integration built-in.

From an AML notebook (create a new file in the "Notebooks" tab), connect to the compute instance you want to use with Pachyderm (creating one through the UI if necessary), and run:

```
!curl -sSL https://raw.githubusercontent.com/pachyderm/aml/main/scripts/install-rslex-custom.sh | bash
```

*Restart the Python Kernel for your notebook after the installation completes,
for the changes to take effect.*

> Note: there might be some errors related to incompatible package versions, you can simply ignore those.

## Step 3 - Connect to Pachyderm

* Install [pachctl](https://docs.pachyderm.com/latest/getting_started/local_installation/#install-pachctl)

We need to get the kubeconfig from Terraform so that we can authenticate against the remote K8s cluster.

From your `aml` repo, run:

```
(cd terraform; terraform output -raw kube_config) > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
pachctl config import-kube aml -k $(cd terraform; terraform output -raw kube_context) --overwrite && pachctl config set active-context aml
pachctl version
```

You should see that your local `pachctl` is able to connect to your Pachyderm cluster.
You can now insert data as described in the [tutorial](#tutorial).

## Tutorial

This tutorial uses structured JSON data, which requires configuring `TF_VAR_pachyderm_syncer_mode="jsonl"`.

First, create a Pachyderm repo:

```
pachctl create repo poker
```

Next, add some data:

```
cat <<EOF | pachctl put file poker@master:/poker.jsonl
{"name": "Gilbert", "wins": [["straight", "7???"], ["one pair", "10???"]]}
{"name": "Alexa", "wins": [["two pair", "4???"], ["two pair", "9???"]]}
{"name": "May", "wins": []}
{"name": "Deloise", "wins": [["three of a kind", "5???"]]}
EOF
```

Then, go to the Datasets page in AML and observe that Pachyderm commits are automatically populated in AML as Dataset versions!
For a specific dataset version, click **Consume** and copy and paste the code into an AML notebook. Run it, and note that the data is visible.

The Consume code should look something like:

```python
from azureml.core import Workspace, Dataset

subscription_id = ''
resource_group = ''
workspace_name = ''

workspace = Workspace(subscription_id, resource_group, workspace_name)

dataset = Dataset.get_by_name(workspace, name='Pachyderm repo poker - jsonl')
dataset.to_pandas_dataframe()
```

> Note: if you get errors, double check 1) the version of your azureml-dataprep libraries and make sure you followed [Step 2](#step-2---update-rslex-on-your-aml-compute) and 2) the data you stored is valid.

Lets create a new version of the data:

```
cat <<EOF | pachctl put file poker@master:/poker.jsonl
{"name": "Albert", "wins": [["straight", "7???"], ["one pair", "10???"]]}
{"name": "Joey", "wins": [["two pair", "4???"], ["two pair", "9???"]]}
{"name": "Luke", "wins": []}
{"name": "Alysha", "wins": [["three of a kind", "5???"]]}
EOF
```

Now re-run the Consume code and show that it's updated. As the *a-ha* moment, go back to the previous version and add `version="1"` to `Dataset.get_by_name()` and show that you see the old version of the data - a-ha! Data versioning & reproducibility!

## More Examples

[Migrate data from Blob/ADLS Gen2 to Pachyderm](examples/azure_storage/README.md)
