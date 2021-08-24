#!/bin/bash

for venv in /anaconda/envs/*; do
    (
        echo "Installing dev version of dataprep libraries for ${venv}"
        ${venv}/bin/pip install --force-reinstall --no-cache-dir --pre --extra-index-url https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/44694458/ azureml-dataprep==2.22.0.dev0+87f3991 azureml-dataprep-rslex==1.20.0.dev0+87f3991
    )
done
