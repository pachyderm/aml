import os, time

import python_pachyderm as pach

import json
from azureml.core import Workspace, Dataset, Datastore, Experiment
from azureml.core.authentication import MsiAuthentication
import base64
import requests

# Track Pachyderm commits that have been propagated
# repo -> commit -> (dataset, version)
commit_to_dataset = {}

print("Connecting to AML workspace")
w = Workspace(
    subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"],
    resource_group=os.environ["AZURE_RESOURCE_GROUP"],
    workspace_name=os.environ["AZURE_ML_WORKSPACE_NAME"],
    auth=MsiAuthentication(),
)
print("Done!")

print("Connecting to Pachyderm")
pc = pach.Client(host=os.environ["PACHD_SERVICE_HOST"], port=os.environ["PACHD_SERVICE_PORT"])
print("Done!")

# Specify "files" to create File datasets (matches all files in the Pachyderm
# repo), or "jsonl" for Tabular json lines format (matches **/*.jsonl in the
# Pachyderm repo).
MODES = {"files", "jsonl", "delimited"}
mode = os.getenv("PACHYDERM_SYNCER_MODE", "jsonl")
if mode not in MODES:
    raise ValueError(f"mode must be one of {MODES}")

# 1. Get all the repos
# 2. For each repo, get all the commits
# 3. For each (repo, commit) see if there's a (dataset, version) that points to it
# 4. If not, create the new (dataset, version)

# TODO: don't create a new version for every existing version every startup
# (parse list of existing, filter them out)


def register_new_dataset_version(ds, mode, repo, commit):
    ds.register(
        workspace=w,
        name=f"Pachyderm repo {repo} - {mode}",
        description=f"Content ({mode}) from Pachyderm repo {repo} at commit {commit}",
        create_new_version=True,
    )
    commit_to_dataset[repo][commit] = ds.id
    print(ds.add_tags({"pachyderm-repo": repo, "pachyderm-commit": commit}))


def update_repos():

    kubeconfig = open(".kube/config").read().encode("utf-8")
    auth = base64.b64encode(kubeconfig).decode("utf-8")

    global pc
    global w
    global commit_to_dataset

    DATASTORE_NAME = "pachyderm_datastore"
    # Does datastore exist?
    if not DATASTORE_NAME in w.datastores:
        print(f"Creating datastore {DATASTORE_NAME}")
        resp = requests.post(
            f"https://ml.azure.com/api/{w.location}/datastore/v1.0/subscriptions/{w.subscription_id}/resourceGroups/{w.resource_group}/providers/Microsoft.MachineLearningServices/workspaces/{w.name}/datastores?createIfNotExists=false&skipValidation=true",
            json={
                "name": DATASTORE_NAME,
                "dataStoreType": "Custom",
                "customSection": {
                    "datastoreType": "Pachyderm",
                    "credential": auth,
                    "properties": {
                        "pachd_service_host": os.environ["PACHD_SERVICE_HOST"],
                        "pachd_service_port": os.environ["PACHD_SERVICE_PORT"],
                    },
                },
            },
            headers=MsiAuthentication().get_authentication_header(),
        )
        print(f"response from creating datastore: {resp} {resp.content}")

    datastore = Datastore.get(workspace=w, datastore_name=DATASTORE_NAME)

    print("Reading repos from pachyderm")
    repos = [ri.repo.name for ri in pc.list_repo()]
    for repo in repos:
        print(f"Visiting {repo}")
        for ci in list(pc.list_commit(repo, reverse=True)):
            if repo not in commit_to_dataset:
                print(f"Propagating commits for repo {repo}")
                commit_to_dataset[repo] = {}

            commit = ci.commit.id
            if commit not in commit_to_dataset[repo]:
                print(f"Propagating commit {repo}@{commit} | {ci}")

                # TODO: rather than switching between modes, consider propagating various views.
                if mode == "files":
                    ds_new = Dataset.File.from_files(
                        # Don't bother checking if files are available at the endpoint
                        validate=False,
                        path=[(datastore, f"{commit}.master.{repo}")],
                    )
                    register_new_dataset_version(ds_new, mode, repo, commit)

                elif mode == "jsonl":
                    ds_new = Dataset.Tabular.from_json_lines_files(
                        # Don't bother checking if files are available at the endpoint
                        validate=False,
                        path=[(datastore, f"{commit}.master.{repo}/**/*.jsonl")],
                    )
                    register_new_dataset_version(ds_new, mode, repo, commit)

                elif mode == "delimited":
                    ds_new = Dataset.Tabular.from_delimited_files(
                        validate=False,
                        # TODO support TSV as well
                        path=[(datastore, f"{commit}.master.{repo}/**/*.csv")],
                    )
                    register_new_dataset_version(ds_new, mode, repo, commit)
                else:
                    raise ValueError(f"{mode} is not recognized as a valid mode, try one of {MODES}")


def loop_update_repos():
    while True:
        update_repos()
        time.sleep(1)


if __name__ == "__main__":
    loop_update_repos()
