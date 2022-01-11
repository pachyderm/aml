#!/bin/bash   
set -xeuo pipefail   
cd language_integrations/azureml-dataprep-rslex
$PYBIN/pip install -U setuptools wheel setuptools-rust pyarrow
$PYBIN/python setup.py develop
$PYBIN/pip install -e .
$PYBIN/pip list | grep rslex