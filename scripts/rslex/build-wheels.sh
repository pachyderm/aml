#!/bin/bash
set -xeuo pipefail

envs=('azureml_py36' 'azureml_py38')
for envname in "${envs[@]}"; do
    (
        echo "Building for ${envname}"
        PYBIN=/anaconda/envs/${envname}/bin
        ${PYBIN}/pip install -U setuptools wheel setuptools-rust pyarrow
        cd language_integrations/azureml-dataprep-rslex
        ${PYBIN}/python setup.py bdist_wheel
    )
done

echo ""
find language_integrations/azureml-dataprep-rslex/dist
