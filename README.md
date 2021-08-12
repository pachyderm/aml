# Pachyderm-AzureML integration: Private Preview Instructions

**Please note: This repo should only be used by Pachyderm-approved private preview users. Please contact [joey@pachyderm.io](mailto:joey@pachyderm.io) to become a private preview user. This is a preview, do not use it for production!**

## Architecture

![Pachyderm and Azure Machine Learning architecture diagram](pachyderm-aml.png)

## Requirements

How to set up AML with Pachyderm:

* You need to be running Linux/MacOS/WSL on your local machine
* Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) 1.0+

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

Choose where you want to deploy Pachyderm and the syncer:
```
export TF_VAR_location="East US"
```

If you're deploying with an existing AzureML workspace, the location above should match where your workspace is.

Now we'll deploy the syncer VM and the AKS cluster and start Pachyderm on it.

Optionally, specify whether you want the syncer to create File datasets (`files`, matches all files, for unstructured data) or Tabular datasets with json lines format (`jsonl`, matches `*.jsonl` and aggregates into a single table - in which case all json lines files in a given Pachyderm repo must have compatible schemas), or Tabular datasets with csv format (`delmited`, matches `*.csv` and aggregates into a single table - in which case all csv files in a given Pachyderm repo must have compatible schemas):

```
export TF_VAR_pachyderm_syncer_mode="files" # or "jsonl" or "delimited"
```

### Option 1: Automatically create a new AzureML workspace and resource group:

```
bash scripts/setup.sh
```

If you get errors about exceeding quota, try a different region (`TF_VAR_location`).

### Option 2: Integrate Pachyderm with an existing AzureML workspace:

If you're attaching AzureML-Pachyderm to an existing AzureML workspace, specify the resource group that the target AzureML workspace is in here, as well as specifying the workspace name:

```
export TF_VAR_existing_resource_group_name="existing-resource-group"
export TF_VAR_existing_workspace_name="existing-workspace"
bash scripts/setup.sh
```

(You can also create a new AzureML workspace in an existing resource group by only specifying `TF_VAR_existing_resource_group_name` but not `TF_VAR_existing_workspace_name`.)


## Step 2 - Update rslex on your AML Compute

Note: this step will no longer be necessary after Microsoft release a new version of rslex.

From an AML notebook (create a new file in the "Notebooks" tab), connect to the compute instance you want to use with Pachyderm (creating one through the UI if necessary), and run:

```
!curl -sSL https://raw.githubusercontent.com/pachyderm/aml/main/scripts/install-rslex-pachyderm-beta.sh | sh
```

Now proceed with the demo or try some of the examples in the `examples/` folder:

## Tutorial

This tutorial uses structured JSON data, which requires running with `TF_VAR_pachyderm_syncer_mode="jsonl"`.

From the directory where you ran `setup.sh`, run:

```
instance_ip="$(cd terraform; terraform output -raw instance_ip)"
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$instance_ip -- '
    echo "{\"name\": \"Gilbert\", \"wins\": [[\"straight\", \"7♣\"], [\"one pair\", \"10♥\"]]}
{\"name\": \"Alexa\", \"wins\": [[\"two pair\", \"4♠\"], [\"two pair\", \"9♠\"]]}
{\"name\": \"May\", \"wins\": []}
{\"name\": \"Deloise\", \"wins\": [[\"three of a kind\", \"5♣\"]]}" > poker.jsonl
    pachctl create repo poker
    pachctl put file poker@master: -f poker.jsonl
'
```

Then, go to the Datasets page in AML and observe that pachyderm commits are automatically populated in AML as Dataset versions!

For a specific dataset version, click Consume and copy and paste the code into an AML notebook. Run it, and note that the data is visible.

Then, run:
```
instance_ip="$(cd terraform; terraform output -raw instance_ip)"
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$instance_ip -- '
    echo "{\"name\": \"Albert\", \"wins\": [[\"straight\", \"7♣\"], [\"one pair\", \"10♥\"]]}
{\"name\": \"Joey\", \"wins\": [[\"two pair\", \"4♠\"], [\"two pair\", \"9♠\"]]}
{\"name\": \"Luke\", \"wins\": []}
{\"name\": \"Alysha\", \"wins\": [[\"three of a kind\", \"5♣\"]]}" > poker.jsonl
    pachctl create repo poker
    pachctl put file poker@master: -f poker.jsonl
'
```

Now re-run the Consume code and show that it's updated, but then as the a-ha moment go back to the previous version and add `version="1"` to the Python code and show that you see the old version of the data - a-ha! Data versioning & reproducibility!

## Advanced: using pachctl locally

This tutorial uses image data, which requires running with `TF_VAR_pachyderm_syncer_mode="files"`.

* Install [pachctl](https://docs.pachyderm.com/latest/getting_started/local_installation/#install-pachctl)

From your `aml` repo, run:

```
(cd terraform; terraform output -raw kube_config) > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
pachctl config set context -k $(terraform output -raw kube_context) aml --overwrite && pachctl config set active-context aml
pachctl version
```

You should see that your local `pachctl` is able to connect to your Pachyderm cluster.
You can now insert data like this:

```
pachctl create repo images
pachctl put file images@master:liberty.png -f http://imgur.com/46Q8nDz.png
pachctl put file images@master:AT-AT.png -f http://imgur.com/8MN9Kg0.png
pachctl put file images@master:kitten.png -f http://imgur.com/g2QnNqa.png
```

And you'll see they automatically show up as dataset versions in AML (if you are running with `pachyderm_syncer_mode` set to `files`).

You may need to click the refresh button in the AML file browser UI to see the downloaded files.
