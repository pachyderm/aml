#!/bin/bash

set -ex pipefail

AZUREML_DATAPREP_VERSION='2.22.0.dev0+87f3991'
PY36_BIN=/anaconda/envs/azureml_py36/bin
PY38_BIN=/anaconda/envs/azureml_py38/bin

echo "Downloading Pachyderm's custom version of azureml-dataprep-rslex"
curl -O https://raw.githubusercontent.com/pachyderm/aml/rslex-dist/rslex-dist/azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp36-cp36m-linux_x86_64.whl
curl -O https://raw.githubusercontent.com/pachyderm/aml/rslex-dist/rslex-dist/azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp38-cp38-linux_x86_64.whl

echo "Install requirements"
$PY36_BIN/pip install --force-reinstall --no-cache-dir --pre --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/ azureml-dataprep==2.22.0.dev0+87f3991
$PY38_BIN/pip install --force-reinstall --no-cache-dir --pre --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/ azureml-dataprep==2.22.0.dev0+87f3991

echo "Installing custom rslex package for Python36"
$PY36_BIN/pip install azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp36-cp36m-linux_x86_64.whl
echo "Installing custom rslex pacakge for Python38"
$PY38_BIN/pip install azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp38-cp38-linux_x86_64.whl

