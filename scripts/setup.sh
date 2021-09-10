#!/bin/bash
set -xeuo pipefail
cd terraform
# For fast manual iteration on the scripts, set SKIP_TERRAFORM=1 after the first run
if [ -z "${SKIP_TERRAFORM:-}" ]; then
    terraform init
    # terraform apply creates env.sh which is consumed by install.sh to configure the syncer
    terraform apply -auto-approve
fi

# for each workspace, create a new syncer
instance_ip="$(terraform output -raw instance_ip)"
trap "echo To debug failures, run: ssh ubuntu@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer" EXIT

if [ -z "${TF_VAR_existing_resource_group_name}" ]; then
    terraform output -raw kube_config > kubeconfig
fi

# Go back to project root
cd ..
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/{syncer,scripts} ubuntu@$instance_ip:
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$instance_ip -- mkdir -p .kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(pwd)/terraform/kubeconfig ubuntu@$instance_ip:.kube/config
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$instance_ip -- bash scripts/install.sh
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$instance_ip -- journalctl -n 100 -f -u pachyderm-aml-syncer
