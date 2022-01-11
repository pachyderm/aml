#!/bin/bash
set -ex pipefail

# Pull the appropriate wheels from aml repo and install them in corresponding Python envs

AZUREML_DATAPREP_VERSION='2.22.0.dev0+87f3991'
PY36_WHEEL=azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp36-cp36m-linux_x86_64.whl
PY38_WHEEL=azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp38-cp38-linux_x86_64.whl
TMPDIR=/tmp/rslex-dist
PY36ENVS=('azureml_py36')
PY38ENVS=('azureml_py38' 'azureml_py38_pytorch' 'azureml_py38_tensorflow')

echo "Downloading Pachyderm's custom version of azureml-dataprep-rslex"
(
    mkdir -p ${TMPDIR}
    cd ${TMPDIR}
    curl -OL https://raw.githubusercontent.com/pachyderm/aml/main/rslex-dist/azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp36-cp36m-linux_x86_64.whl
    curl -OL https://raw.githubusercontent.com/pachyderm/aml/main/rslex-dist/azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp38-cp38-linux_x86_64.whl
)

for envname in "${PY36ENVS[@]}"; do
    echo "Installing for ${envname}"
    pip=/anaconda/envs/${envname}/bin/pip
    $pip install --force-reinstall --no-cache-dir --pre --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/ azureml-dataprep==$AZUREML_DATAPREP_VERSION
    $pip install ${TMPDIR}/${PY36_WHEEL}
done

for envname in "${PY38ENVS[@]}"; do
    echo "Installing for ${envname}"
    pip=/anaconda/envs/${envname}/bin/pip
    $pip install --force-reinstall --no-cache-dir --pre --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/ azureml-dataprep==$AZUREML_DATAPREP_VERSION
    $pip install ${TMPDIR}/${PY38_WHEEL}
done
