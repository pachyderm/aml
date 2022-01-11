# rslex (DataPrep RustLex)

[GitHub Repo](https://github.com/Azure/rslex)

`rslex` is the client library to interface with Azure ML Datasets.

At a high level, the user will use rslex to request data from Datasets, which are path references to Datastores. rslex takes those paths and queries the underlying datastore, which is a Pachyderm cluster. You can imagine these Datasets as S3 glob patterns for specific repo+commit combos, for example `[commit].[branch].[repo]/**.jsonl` 

# Development environment

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
        
6. Run your first  build `cargo build`
7. Open `rslex-pachyderm/src/pachyderm_stream_handler/stream_handler.rs` and see if the Rust tooling recognizes it.
8. Congrats, you are ready to Rust!

## Troubleshooting this setup

If you encounter an error like “Failed to start Rust server” while opening up a Rust file, then you might need to try the following steps:

- restart vscode closing it and opening it again via the Azure ML portal
- re-install the Rust extension
- restart VM

# Relephant info

Start here: `[readme.md](http://readme.md)` for example `cargo` commands

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

# Old but maybe still relevant

[https://github.com/pachyderm/azureml-demo-syncer/blob/terraform/setup.md](https://github.com/pachyderm/azureml-demo-syncer/blob/terraform/setup.md)

```
add pdb.set_trace() to the following to see rslex errors from Python
<python_env>/site-packages/azureml/dataprep/api/_rslex_executor.py
```