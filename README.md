# How to set up AML with Pachyderm

## Step 1 - Deploy stack

* Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

Log into Azure:
```
az login
```

Set up Terraform environment variables:
```
export TF_VAR_prefix=foo
export TF_VAR_location="East US"
```

TODO: make it possible to pass an existing AML workspace into the setup script as an argument.

Clone this repo and run the setup script.

TODO: make this work

```
git clone https://github.com/pachyderm/aml
cd aml
bash scripts/setup.sh
```


## Step 2 - Update rslex on your AML Compute

Note: this step will no longer be necessary after Microsoft release a new version of rslex.

From an AML notebook (create a new file in the "Notebooks" tab), connect to the compute instance you want to use with Pachyderm, and run:

```
!curl -sSL https://raw.githubusercontent.com/pachyderm/aml/main/scripts/install-rslex-pachyderm-beta.sh | sh
```

Now proceed with the demo...

## Demo

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

Then click Consume and copy and paste the result into an AML notebook.

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

Now re-run the Consume code and show that it's updated, but then as the a-ha moment go back to the previous version and add `version="1"` to the Python code and show that you see the old version of the data - a-ha! Reproducibility!
