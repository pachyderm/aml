import base64
import os
import time

import python_pachyderm as pach
import requests
from azureml.core import Dataset, Datastore, Workspace
from azureml.core.authentication import MsiAuthentication

print("Connecting to AML workspace")
WORKSPACE = Workspace(
    subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"],
    resource_group=os.environ["AZURE_RESOURCE_GROUP"],
    workspace_name=os.environ["AZURE_ML_WORKSPACE_NAME"],
    auth=MsiAuthentication(),
)
print("Done!")

print("Connecting to Pachyderm")
PC = pach.Client(
    host=os.environ["PACHD_SERVICE_HOST"], port=os.environ["PACHD_SERVICE_PORT"]
)
print("Done!")

# Specify "files" to create File datasets (matches all files in the Pachyderm
# repo), or "jsonl" for Tabular json lines format (matches **/*.jsonl in the
# Pachyderm repo).
MODES = {"files", "jsonl", "delimited"}
MODE = os.getenv("PACHYDERM_SYNCER_MODE", "jsonl")
if MODE not in MODES:
    raise ValueError(f"mode must be one of {MODES}")

# 1. Get all the repos
# 2. For each repo, get all the commits
# 3. For each (repo, commit) see if there's a (dataset, version) that points to it
# 4. If not, create the new (dataset, version)
# Track Pachyderm commits that have been propagated
existing_commits = set()


def register_new_dataset_version(ds, mode, repo, commit):
    ds.register(
        workspace=WORKSPACE,
        name=f"Pachyderm repo {repo} - {mode}",
        description=f"Content ({mode}) from Pachyderm repo {repo} at commit {commit}",
        create_new_version=True,
        tags={"pachyderm-repo": repo, "pachyderm-commit": commit},
    )
    existing_commits.add(commit)


def get_existing_dataset_commits():
    # get all registered Datasets, returns a dictionary of datasets keyed by their registration name
    datasets = Dataset.get_all(WORKSPACE)
    for dataset_name, dataset in datasets.items():
        latest_version = dataset.version

        for version in range(1, latest_version + 1):
            dataset = Dataset.get_by_name(WORKSPACE, dataset_name, version)
            commit = dataset.tags.get("pachyderm-commit", None)
            if commit is not None:
                existing_commits.add(commit)


def update_repos():

    kubeconfig = open(".kube/config").read().encode("utf-8")
    auth = base64.b64encode(kubeconfig).decode("utf-8")

    DATASTORE_NAME = "pachyderm_datastore"
    # Does datastore exist?
    if DATASTORE_NAME not in WORKSPACE.datastores:
        print(f"Creating datastore {DATASTORE_NAME}")
        resp = requests.post(
            f"https://ml.azure.com/api/{WORKSPACE.location}/datastore/v1.0/subscriptions/{WORKSPACE.subscription_id}/resourceGroups/{WORKSPACE.resource_group}/providers/Microsoft.MachineLearningServices/workspaces/{WORKSPACE.name}/datastores?createIfNotExists=false&skipValidation=true",
            json={
                "name": DATASTORE_NAME,
                "dataStoreType": "Custom",
                "customSection": {
                    "datastoreType": "Pachyderm",
                    "credential": auth,
                    "properties": {
                        "pachd_service_host": os.environ.get("PACHD_SERVICE_HOST", "localhost"),
                        "pachd_service_port": os.environ.get("PACHD_SERVICE_PORT", 30650),
                        "pachd_s3g_port": os.environ.get("PACHD_S3G_PORT", 30600),
                    },
                },
            },
            headers=MsiAuthentication().get_authentication_header(),
        )
        print(f"response from creating datastore: {resp} {resp.content}")

    datastore = Datastore.get(workspace=WORKSPACE, datastore_name=DATASTORE_NAME)

    print("Reading repos from pachyderm")
    repos = [ri.repo.name for ri in PC.list_repo()]
    for repo in repos:
        print(f"Visiting {repo}")
        for ci in list(PC.list_commit(repo, reverse=True)):
            commit = ci.commit.id
            if commit not in existing_commits:
                print(f"Propagating commit {repo}@{commit} | {ci}")

                # TODO: rather than switching between modes, consider propagating various views.
                if MODE == "files":
                    ds = Dataset.File.from_files(
                        # Don't bother checking if files are available at the endpoint
                        validate=False,
                        path=[(datastore, f"{commit}.master.{repo}")],
                    )
                    register_new_dataset_version(ds, MODE, repo, commit)

                elif MODE == "jsonl":
                    ds = Dataset.Tabular.from_json_lines_files(
                        # Don't bother checking if files are available at the endpoint
                        validate=False,
                        path=[(datastore, f"{commit}.master.{repo}/**.jsonl")],
                    )
                    register_new_dataset_version(ds, MODE, repo, commit)

                elif MODE == "delimited":
                    ds = Dataset.Tabular.from_delimited_files(
                        validate=False,
                        infer_column_types=False,
                        # TODO support TSV as well
                        path=[(datastore, f"{commit}.master.{repo}/**.csv")],
                    )
                    register_new_dataset_version(ds, MODE, repo, commit)
                else:
                    raise ValueError(
                        f"{MODE} is not recognized as a valid mode, try one of {MODES}"
                    )


def loop_update_repos():
    while True:
        update_repos()
        time.sleep(1)


if __name__ == "__main__":
    get_existing_dataset_commits()
    print("existing commits", existing_commits)
    loop_update_repos()
