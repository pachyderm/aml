#!/bin/bash
set -e

source /home/pachyderm/env.sh

PACHD_VERSION='2.0.0-rc.1'

if [[ -z "$SKIP_PACHYDERM_DEPLOY" ]]; then
    helm repo add pach https://helm.pachyderm.com
    helm repo update
    helm install -f helmvalues.yaml pachd pach/pachyderm --version ${PACHD_VERSION}
fi

echo "Wait for pachd to finish deploying with timeout=3m"
kubectl wait --for=condition=ready --timeout=3m pod -l app=pachd
