#!/bin/bash -ex

PACHD_VERSION='2.0.0-rc.1'

# Install dependencies

# pip
sudo apt-get update && apt-get upgrade -y
sudo apt-get -y install python3-pip
python3 -m pip --version

## helm
curl -LO https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz
tar -zxvf helm-v3.7.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm-v3.7.0-linux-amd64.tar.gz
helm version

## kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
## pachctl
curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v${PACHD_VERSION}/pachctl_${PACHD_VERSION}_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

# Setup sudo to allow no-password sudo for "pachyderm" user
sudo groupadd -r hashicorp
sudo useradd -m -s /bin/bash pachyderm
sudo cp /etc/sudoers /etc/sudoers.orig
echo "pachyderm ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/pachyderm
sudo chown -R pachyderm /home/pachyderm

# Do everything as "pachyderm" user
sudo -i -u pachyderm bash << EOF
python3 -m pip install --upgrade pip
python3 -m pip install setuptools-rust==0.12.1 python-pachyderm==7.0.0rc1

# Install dev build of azureml-dataprep which supports custom datastores
# These two are compatible versions
python3 -m pip install  --extra-index-url=https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ \
  azureml-dataprep==2.18.0.dev0+98293a5
python3 -m pip install azureml-core==1.29.0.post1

# Create paths to run syncer in VM instances
cd /home/pachyderm
mkdir -p \
  .kube \
  scripts \
  syncer

cp /tmp/start.sh /tmp/deploy_pachyderm.sh /home/pachyderm/scripts
cp /tmp/sync.py /home/pachyderm/syncer/sync.py

chmod +x /home/pachyderm/scripts/start.sh
EOF

# create a service in systemd to run syncer
cat << EOF | sudo tee /etc/systemd/system/pachyderm-aml-syncer.service
[Unit]
Description=Pachyderm AzureML Syncer

[Service]
User=pachyderm
WorkingDirectory=/home/pachyderm
ExecStart=/home/pachyderm/scripts/start.sh
Environment=PYTHONUNBUFFERED=1
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable pachyderm-aml-syncer.service
