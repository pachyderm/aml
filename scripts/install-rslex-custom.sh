#!/bin/bash
set -ex pipefail

# Pull the appropriate wheels from aml repo and install them in corresponding Python envs

# <<< Only need to update the following for new releases
AZUREML_DATAPREP_VERSION='2.22.0.dev0+87f3991'
EXTRA_PYPI_URL=https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/
PY36_WHEEL=azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp36-cp36m-linux_x86_64.whl
PY38_WHEEL=azureml_dataprep_rslex-1.20.0.dev0%2B681316a-cp38-cp38-linux_x86_64.whl
# >>>

TMPDIR=/tmp/rslex-dist
PY36ENVS=('azureml_py36')
PY38ENVS=('azureml_py38' 'azureml_py38_pytorch' 'azureml_py38_tensorflow')

(
    echo "Downloading custom built versions of azureml-dataprep-rslex"
    mkdir -p ${TMPDIR}
    cd ${TMPDIR}
    curl -OL https://raw.githubusercontent.com/pachyderm/aml/main/rslex-dist/${PY36_WHEEL}
    curl -OL https://raw.githubusercontent.com/pachyderm/aml/main/rslex-dist/${PY38_WHEEL}
)

for envname in "${PY36ENVS[@]}"; do
    echo "Installing for ${envname}"
    pip=/anaconda/envs/${envname}/bin/pip
    $pip install --force-reinstall --no-cache-dir --pre --extra-index-url $EXTRA_PYPI_URL azureml-dataprep==$AZUREML_DATAPREP_VERSION
    $pip install ${TMPDIR}/${PY36_WHEEL}
done

for envname in "${PY38ENVS[@]}"; do
    echo "Installing for ${envname}"
    pip=/anaconda/envs/${envname}/bin/pip
    $pip install --force-reinstall --no-cache-dir --pre --extra-index-url $EXTRA_PYPI_URL azureml-dataprep==$AZUREML_DATAPREP_VERSION
    $pip install ${TMPDIR}/${PY38_WHEEL}
done
