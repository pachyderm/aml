# rslex (DataPrep RustLex)

[GitHub Repo](https://github.com/Azure/rslex)

`rslex` is a low level released as part of `azureml-dataprep-rslex`, which is used by the higher level `azureml-dataprep` libraries.

At a high level, the code path looks something like:

1. [Python] user creates a lazy `Dataset` based on some name or path referencing some data in Pachyderm.
1. [Python] user calls some function to "download Dataset"
1. [Python] the Dataset API forwards the request to rslex
1. [Rust] the request looks something like `{data_store_type: "pachyderm", path: "commit.branch.repo/**.jsonl"}`
1. [Rust] rslex forwards the request to our custom handler
1. [Rust] handler makes an HTTP request to Pachyderm via S3G
1. [Rust] returns file content back to the user

For reference:

- [`Dataset`](https://docs.microsoft.com/en-us/python/api/azureml-core/azureml.core.dataset(class)?view=azure-ml-py)
- [`Datastore`](https://docs.microsoft.com/en-us/python/api/azureml-core/azureml.core.datastore.datastore?view=azure-ml-py)
- [Dataset tutorial](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-create-register-datasets)


# Development environment in AML VM

The repo details how to get a local dev environment setup. However, because we are building an integration with Azure ML itself, we need to test whether our stuff actually works with the Azure ML environment. To test this, we need to create a real Azure ML workspace, and a VM computer instance as our development computer.

1. Create AML workspace and compute instance (doesn’t need to be super powerful, but RAM is important for Rust compilation)
2. In your local vscode, install the [Azure Machine Learning extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.vscode-ai)
3. Once the VM is ready, click on `VS Code` under **Applications**. This will open up vscode.
4. Get the code
    1. at first your directory will be something like `~/cloudfiles/code` , but we want `/home/azureuser` , so click through **File > Open Folder...** to open the home dir
    2. generate an ssh key with `ssh-keygen`
    3. Upload `~/.ssh/id_rsa.pub` to your GitHub
    4. clone the rslex repo
    5. open workspace at rslex repo as root **File > Open Folder...** select `/home/azureuser/rslex`
5. Install Rust tooling
    1. install `rustup` [https://rustup.rs/](https://rustup.rs/)
    2. [Rust Extension](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust) for vscode (on the server)
    3. Follow the steps at [https://github.com/Azure/rslex#option-2-install-required-tools](https://github.com/Azure/rslex#option-2-install-required-tools)
        1. Note: for the `apt install` command, you may need `sudo apt update` first
    4. install additional tools
        
        ```
        rustup component add rust-analysis rust-src rls --toolchain nightly-2021-03-13-x86_64-unknown-linux-gnu
        ```
6. Run `cargo check` to quickly verify
7. Open a `.rs` file to see if vscode recognizes it.
8. Congrats, you are ready to become a Rustacean!

## How to build the rslex Python package

Although rslex is a Rust library, our goal is to build a Python package that the end user can use.

### Build and install in editable mode for development

1. Pick a Python env, for example
   ```
   export PYBIN=/anaconda/envs/azureml_py36/bin
   ```
1. Copy the [`build-and-install-rslex.sh`](scripts/rslex/build-and-install-rslex.sh) to your VM in the root rslex directory
1. Run `build-and-install-rslex.sh`
1. The development mode version of the azureml-dataprep-rslex libary should now be installed in the environment specified by `PYBIN`

### Build Python distrubtions

If we don't want to wait for Microsoft to release a new version of rslex, then we need to build our own and distribute it as custom wheels.

1. Copy [`build-wheel-for-distribution.sh`](scripts/rslex/build-wheel-for-distribution.sh) to your VM.
1. Run `build-wheels.sh`
1. Copy `language_integrations/azureml-dataprep-rslex/dist/*.whl` to this repo's `rslex-dist` directory.

## Troubleshooting this setup

If you encounter an error like “Failed to start Rust server” while opening up a Rust file, then you might need to try the following steps:

- restart vscode closing it and opening it again via the Azure ML portal
- re-install the Rust extension
- restart VM

# Relephant info

`rslex/src/execution/operations/get_files.rs`

- `get_files()` this is the entrypoint called by the Python client to get files for a Dataset

`rslex-pachyderm/src/pachyderm_stream_handler/stream_handler.rs`

- The entry point for pachyderm specific functionality in rslex. Embeds a normal HTTP client.
- Triggers the `searcher`.
- `stream_handler` converts a specific instance of the list returned by searcher to the actual bytes that exist in that object
- GET /some-specific-objects
    - returns the actual object itself as a regular HTTP response body, in which case, we can just use the rslex-http-stream http client library

`rslex-pachyderm/src/pachyderm_stream_handler/request_builder.rs`

- attempt port-forward on instantiation

`rslex-pachyderm/src/pachyderm_stream_handler/s3_utils.rs`

- job of searcher is to convert a search request (e.g. `"commit.branch.repo/*/**.jsonl"`) into a list of streams (specific objects), like `["poker.jsonl", "hodlem.jsonl"]`
- `GET / or GET /some_prefix`
- returns an XML response with a list of objects (paginated)
- using rust-s3 lib to parse that XML so we don't have to

`rslex-fuse/src/direct_volume_mount/mod.rs`

## ENV variables to set for testing

`DPREP_RSLEX_LOG_STDOUT`  for printing out logs via tracing::debug! to stdout

`RSLEX_DIRECT_VOLUME_MOUNT=true`  for testing directory volume mounts

## Python testing code

To test glob pattern (default), you can just copy the **consume** code in the Azure ML web UI.

For example:

```python
from azureml.core import Workspace, Dataset

subscription_id = ''
resource_group = ''
workspace_name = ''

workspace = Workspace(subscription_id, resource_group, workspace_name)

dataset = Dataset.get_by_name(workspace, name='Pachyderm repo poker - jsonl view')
print(dataset.to_pandas_dataframe())
```

To test the mount feature

```python
from azureml.core import Workspace, Dataset, Datastore
import os
import pprint

subscription_id = ''
resource_group = ''
workspace_name = ''

datastore_name = "pachyderm_datastore"

workspace = Workspace(subscription_id, resource_group, workspace_name)
datastore = Datastore.get(workspace=workspace, datastore_name=datastore_name)

commit = ""
branch = ""
repo = ""
container = f"{commit}.{branch}.{repo}"
path = ""
dataset = Dataset.File.from_files(path=[(datastore, f"{container}/{path}")])

with dataset.mount() as mount_ctx:
    mp = mount_ctx.mount_point
    print("mount point =", mp)
    pprint.pprint(list(os.walk(mp)))
```

To test getting a single file

```python
from azureml.core import Workspace, Dataset, Datastore

subscription_id = ''
resource_group = ''
workspace_name = ''
datastore_name = "pachyderm_datastore"

workspace = Workspace(subscription_id, resource_group, workspace_name)
datastore = Datastore.get(workspace=workspace, datastore_name=datastore_name)

dataset = Dataset.Tabular.from_json_lines_files(path=[(datastore, 'commit.branch.repo/filepath')])
print(dataset.to_pandas_dataframe())
```

The Python side of the datarep library swallows up meaningful rslex errors, so if you get some generic error like

```
Error Message: ScriptExecutionException was caused by StreamAccessException.
  StreamAccessException was caused by ValidationException.
    Attempting to get files from Datastore '(pachyderm_datastore)' of type 'Custom' in subscription: 'blah', resource group: 'blah', workspace: 'blah'.
Datastore of this type is not curently supported.
```

then try to add `pdb.set_trace()` to `<python_env>/site-packages/azureml/dataprep/api/_rslex_executor.py` to get the errors from rslex.

# Old but still relephant

https://github.com/pachyderm/azureml-demo-syncer/blob/terraform/setup.md

https://github.com/pachyderm/azureml-demo-syncer/blob/terraform/packer.json


