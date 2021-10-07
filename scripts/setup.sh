#!/bin/bash
set -xeuo pipefail

# Directory containing terraform scripts
[[ -z ${TERRAFORM_WD:-} ]] && TERRAFORM_WD=$(pwd)/terraform

# kubeconfig must already exist if user wants to skip deploying Pachyderm
if [[ ! -z "${TF_VAR_skip_pachyderm_deploy:+x}" ]] && [[ ! -f "$TERRAFORM_WD/out/kubeconfig" ]]; then
  echo "\"$TERRAFORM_WD/out/kubeconfig\" does not exist, but Pachyderm deployment is skipped; exiting" >/dev/stderr
  exit 1
fi

pushd $TERRAFORM_WD
# For fast manual iteration on the scripts, set SKIP_TERRAFORM=1 after the first run
if [ -z "${SKIP_TERRAFORM:-}" ]; then
    terraform init
    # terraform apply creates env.sh which is consumed by install.sh to configure the syncer
    terraform apply -auto-approve
fi

instance_ip="$(terraform output -raw instance_ip)"
trap "echo To debug failures, run: ssh pachyderm@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer" EXIT

[[ -z "${TF_VAR_skip_pachyderm_deploy:+x}" ]] && terraform output -raw kube_config > out/kubeconfig

popd
# copy over env variables and kubeconfig
kubeconfig=$TERRAFORM_WD/out/kubeconfig
if [[ -f ${kubeconfig} ]]; then
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ${kubeconfig} pachyderm@$instance_ip:/home/pachyderm/.kube/config
else
    echo "error: ${kubeconfig} not found"
    exit 1
fi

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ${TERRAFORM_WD}/out/{env.sh,helmvalues.yaml} pachyderm@$instance_ip:/home/pachyderm

# deploy pachyderm and run syncer
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pachyderm@$instance_ip -- bash scripts/deploy_pachyderm.sh
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pachyderm@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer
