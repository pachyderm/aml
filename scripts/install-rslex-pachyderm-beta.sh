#!/bin/bash

export PY36_VERSION=507d32b
export PY38_VERSION=507d32b

echo "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "Installing Microsoft's dev version of dataprep for py36"
/anaconda/envs/azureml_py36/bin/pip install --force-reinstall --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ azureml-dataprep==2.18.0.dev0+98293a5

echo "Installing Pachyderm's version of rslex for py36"
curl -LO https://github.com/pachyderm/aml/raw/main/dist/azureml_dataprep_rslex-1.16.0.dev0%2B${PY36_VERSION}-cp36-cp36m-linux_x86_64.whl
/anaconda/envs/azureml_py36/bin/pip install azureml_dataprep_rslex-1.16.0.dev0%2B${PY36_VERSION}-cp36-cp36m-linux_x86_64.whl

echo "Installing Microsoft's dev version of dataprep for py38"
/anaconda/envs/azureml_py38/bin/pip install --force-reinstall --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ azureml-dataprep==2.18.0.dev0+98293a5

echo "Installing Pachyderm's version of rslex for py38"
curl -LO https://github.com/pachyderm/aml/raw/main/dist/azureml_dataprep_rslex-1.16.0.dev0%2B${PY38_VERSION}-cp38-cp38-linux_x86_64.whl
/anaconda/envs/azureml_py38/bin/pip install azureml_dataprep_rslex-1.16.0.dev0%2B${PY38_VERSION}-cp38-cp38-linux_x86_64.whl
