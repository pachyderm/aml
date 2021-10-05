#!/bin/bash
set -xeuo pipefail
cd terraform
# For fast manual iteration on the scripts, set SKIP_TERRAFORM=1 after the first run
if [ -z "${SKIP_TERRAFORM:-}" ]; then
    terraform init
    # terraform apply creates env.sh which is consumed by install.sh to configure the syncer
    terraform apply -auto-approve
fi

instance_ip="$(terraform output -raw instance_ip)"
trap "echo To debug failures, run: ssh pachyderm@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer" EXIT

[[ -z "${TF_VAR_skip_pachyderm_deploy}" ]] && terraform output -raw kube_config > kubeconfig

cd ..
# copy over env variables and kubeconfig
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/terraform/kubeconfig pachyderm@$instance_ip:/home/pachyderm/.kube/config
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/scripts/{env.sh,helmvalues.yaml} pachyderm@$instance_ip:/home/pachyderm

# deploy pachyderm and run syncer
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pachyderm@$instance_ip -- bash scripts/deploy_pachyderm.sh
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pachyderm@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer
