# How to version data in Azure Blob or ADLS Gen2 with Pachyderm

This tutorial goes over how to setup a Pachyderm pipeline that copies data from either Azure Blob or Azure Data Lake Storage (ADLS) Gen2 to a Pachyderm repo.

## Requirements

- Azure Storage Account and Key
- az
- kubectl
- pachctl

## Steps

For each Azure Storage Container do

1. Generate a SAS token for authorizing Pachyderm pipelines to read from Azure Storage
    - set the expiry date accordingly
    - allow (r)ead and (l)ist permissions

    ```
    az storage container generate-sas \
        --account-key 00000000 \
        --account-name mystorageaccount \
        --name mycontainer \
        --expiry 2021-08-27 \
        --permissions rl
    ```

2. Copy the token, and create a K8s secret for it

    ```
    kubectl create secret generic container_name_secret \
        --from-literal=azure_storage_sas_token='AZURE_STORAGE_SAS_TOKEN'
    ```

3. Copy `pipeline_example.json` and rename it to something like `pipeline_container_name.json`, where `container_name` is the Azure Storage Container.

    - set `pipeline_name` to your Container name, so that the pipeline creates a Pachyderm repo with the same name.
    - `AZURE_STORAGE_TYPE` differentiates between Blob Storage and ADLS Gen2
        - Blob Storage -> `blob`
        - ADLS Gen2 -> `dfs`
    - set the cron spec to the desired frequency

4. Deploy pipeline to Pachyderm:

    ```
    pachctl create pipeline -f pipeline_container_name.json
    ```

## How it works

Data in Azure Blob/ADLS Gen2 is organized under Storage Account + Container. We model the system as:


| Azure      | Pachyderm |
| ----------- | ----------- |
| Storage Account      | Cluster |
| Container   | Repo        |
| Blob | File |
| ADLS Gen2 File | File |
| ADLS Gen2 Directory | Directory |



Pipeline: 

```
Azure Storage (Blob/ADLS Gen2) -> Pachyderm Cron Pipeline -> Pachyderm Repo
```

Each pipeline is responsible for copying data from a single Azure Container to a Pachyderm Repo. This pipeline runs within Pachyderm, so its output is automatically versioned.
