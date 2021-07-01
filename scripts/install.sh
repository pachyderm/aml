#!/bin/bash
set -xeuo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export PYTHONUNBUFFERED=1

# Created by terraform
source $SCRIPT_DIR/env.sh

# TODO: bake this into a dockerfile or VM image or something.

sudo apt update
sudo apt install -y python3-pip

pip3 install --upgrade pip

pip3 install \
  setuptools-rust==0.12.1

pip3 install \
  python-pachyderm==6.1.0

# Install dev build of azureml-dataprep which supports custom datastores

# These two are compatible versions
pip3 install --extra-index-url=https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ \
  azureml-dataprep==2.18.0.dev0+98293a5
pip3 install azureml-core==1.29.0.post1

# Install kubectl, setup.sh has already put .kube/config in place

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Set up pachyderm on AKS cluster

curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v1.13.3/pachctl_1.13.3_amd64.deb \
    && sudo dpkg -i /tmp/pachctl.deb

#pachctl deploy microsoft <container> <account-name> <account-key> <disk-size>
pachctl deploy microsoft --dry-run --dynamic-etcd-nodes 1 \
    $AZURE_STORAGE_CONTAINER $AZURE_STORAGE_ACCOUNT_NAME $AZURE_STORAGE_ACCOUNT_KEY 50 > pachyderm.yaml
#sed -i "s/:1.13.1/:1.13.2-caa0df0c871d9af6c9c87c3ee55684d2f4cd34ad/g" pachyderm.yaml
kubectl apply -f pachyderm.yaml

until timeout 1s bash $SCRIPT_DIR/check_ready.sh app=pachd; do sleep 1; done

kubectl get all

pkill -f 'port-forward' || true

# give pachd a chance to bind its ports
# TODO: less hacky way to do this?
echo "Waiting for 30 seconds for pachd to bind its ports before proceeding..."
sleep 30

kubectl port-forward service/pachd 30650:650 &
pid=$!

echo "Waiting for 15 seconds for port forwarding to start working before proceeding..."
sleep 15
if [ ! -e /proc/$pid/cmdline ]; then
    echo "Port-forward exited, oh no"
    exit 1
fi

#echo "Starting syncer"
#python3 syncer/sync.py

cat << EOF | sudo tee -a /etc/systemd/system/pachyderm-aml-syncer.service
[Unit]
Description=Pachyderm AzureML Syncer
[Service]
User=root
WorkingDirectory=/home/ubuntu
ExecStart=/bin/bash -c "source /home/ubuntu/scripts/env.sh; /usr/bin/python3 /home/ubuntu/syncer/sync.py"
Environment=PYTHONUNBUFFERED=1
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start pachyderm-aml-syncer
