#!/bin/bash
set -xeuo pipefail

for PYBIN in /anaconda/envs/*/bin; do
    (
        cd language_integrations/azureml-dataprep-rslex
        ${PYBIN}/pip install setuptools-rust
        ${PYBIN}/pip install pyarrow
        ${PYBIN}/pip install -U setuptools wheel setuptools-rust
        ${PYBIN}/python setup.py develop
        ${PYBIN}/python setup.py bdist_wheel
    )
done

echo ""
find language_integrations/azureml-dataprep-rslex/dist
