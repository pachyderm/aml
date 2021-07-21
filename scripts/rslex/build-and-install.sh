#!/bin/bash
set -xeuo pipefail

# enum34 breaks pip install below, similar to this...
# https://github.com/iterative/dvc/issues/1995
pip uninstall enum34 || true

(
    set -xeuo pipefail
    cd language_integrations/azureml-dataprep-rslex
    pip install setuptools-rust
    pip install pyarrow
    python3.8 setup.py develop
    pip install -e .
)
