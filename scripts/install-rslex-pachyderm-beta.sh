#!/bin/bash

export PY36_VERSION=56aabab
export PY38_VERSION=56aabab
export PY36_BIN=/anaconda/envs/azureml_py36/bin
export PY38_BIN=/anaconda/envs/azureml_py38/bin

echo "Installing Microsoft's dev version of dataprep for py36"
${PY36_BIN}/pip install --force-reinstall --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ azureml-dataprep==2.18.0.dev0+98293a5

echo "Installing Pachyderm's version of rslex for py36"
curl -LO https://github.com/pachyderm/aml/raw/main/dist/azureml_dataprep_rslex-1.16.0.dev0%2B${PY36_VERSION}-cp36-cp36m-linux_x86_64.whl
${PY36_BIN}/pip install azureml_dataprep_rslex-1.16.0.dev0%2B${PY36_VERSION}-cp36-cp36m-linux_x86_64.whl

echo "Installing Microsoft's dev version of dataprep for py38"
${PY38_BIN}/pip install --force-reinstall --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ azureml-dataprep==2.18.0.dev0+98293a5

echo "Installing Pachyderm's version of rslex for py38"
curl -LO https://github.com/pachyderm/aml/raw/main/dist/azureml_dataprep_rslex-1.16.0.dev0%2B${PY38_VERSION}-cp38-cp38-linux_x86_64.whl
${PY38_BIN}/pip install azureml_dataprep_rslex-1.16.0.dev0%2B${PY38_VERSION}-cp38-cp38-linux_x86_64.whl

# Upgrade azureml-core because Azure ML compute instances currently comes with an outdated version
echo "Upgrading azureml-core to 1.32.0 just incase Azure ML compute comes with an incompatible version"
${PY36_BIN}/pip install --upgrade azureml-core==1.32.0
${PY38_BIN}/pip install --upgrade azureml-core==1.32.0

