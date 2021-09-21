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
trap "echo To debug failures, run: ssh ubuntu@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer" EXIT

terraform output -raw kube_config > kubeconfig

cd ..
# copy over env variables and kubeconfig
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/terraform/kubeconfig terraform@$instance_ip:/home/terraform/.kube/config
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/scripts/env.sh terraform@$instance_ip:/home/terraform/env.sh
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/scripts/helmvalues.yaml terraform@$instance_ip:/home/terraform/helmvalues.yaml
# deploy pachyderm and run syncer
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null terraform@$instance_ip -- bash scripts/deploy_pachyderm.sh
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null terraform@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer
