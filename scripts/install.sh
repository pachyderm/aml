#!/bin/bash
set -xeuo pipefail

PACHD_VERSION='2.0.0-rc.1'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export PYTHONUNBUFFERED=1

# Created by terraform
source $SCRIPT_DIR/env.sh

# we will use Packer to create a VM image

# Install helm
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update

sudo apt-get install -y python3-pip helm

pip3 install --upgrade pip
pip3 install setuptools-rust==0.12.1 python-pachyderm==7.0.0rc1

# Install dev build of azureml-dataprep which supports custom datastores
# These two are compatible versions
pip3 install --extra-index-url=https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ \
  azureml-dataprep==2.18.0.dev0+98293a5
pip3 install azureml-core==1.29.0.post1

# Install kubectl, setup.sh has already put .kube/config in place
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Set up Pachyderm on AKS cluster
helm repo add pach https://helm.pachyderm.com
helm repo update
helm install -f ${SCRIPT_DIR}/helmvalues.yaml pachd pach/pachyderm --version ${PACHD_VERSION}

# Install pachctl
curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v${PACHD_VERSION}/pachctl_${PACHD_VERSION}_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

until timeout 1s bash $SCRIPT_DIR/check_ready.sh app=pachd; do sleep 1; done

kubectl get all

echo "Waiting for 30 seconds for pachd to bind its ports before proceeding..."
sleep 30

# Use systemd to run syncer
cat << EOF | sudo tee /etc/systemd/system/pachyderm-aml-syncer.service
[Unit]
Description=Pachyderm AzureML Syncer

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/scripts/start.sh
Environment=PYTHONUNBUFFERED=1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start pachyderm-aml-syncer
