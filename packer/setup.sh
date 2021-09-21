#!/bin/bash -ex

PACHD_VERSION='2.0.0-rc.1'

# Install dependencies

## helm
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y python3-pip helm
## kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
## pachctl
curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v${PACHD_VERSION}/pachctl_${PACHD_VERSION}_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

# Setup sudo to allow no-password sudo for "hashicorp" group and adding "terraform" user
sudo groupadd -r hashicorp
sudo useradd -m -s /bin/bash terraform
sudo usermod -a -G hashicorp terraform
sudo cp /etc/sudoers /etc/sudoers.orig
echo "terraform ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/terraform
sudo chown -R terraform /home/terraform

# Do everything as "terraform" user
sudo -i -u terraform bash << EOF
python3 -m pip install --upgrade pip
python3 -m pip install setuptools-rust==0.12.1 python-pachyderm==7.0.0rc1

# Install dev build of azureml-dataprep which supports custom datastores
# These two are compatible versions
python3 -m pip install  --extra-index-url=https://dataprepdownloads.azureedge.net/pypi/test-M3ME5B1GMEM3SW0W/38723857/ \
  azureml-dataprep==2.18.0.dev0+98293a5
python3 -m pip install azureml-core==1.29.0.post1

# Create paths to run syncer in VM instances
cd /home/terraform
mkdir -p \
  .kube \
  scripts \
  syncer

cp /tmp/start.sh /tmp/deploy_pachyderm.sh /home/terraform/scripts
cp /tmp/sync.py /home/terraform/syncer/sync.py

chmod +x /home/terraform/scripts/start.sh
EOF

# create a service in systemd to run syncer
cat << EOF | sudo tee /etc/systemd/system/pachyderm-aml-syncer.service
[Unit]
Description=Pachyderm AzureML Syncer

[Service]
User=terraform
WorkingDirectory=/home/terraform
ExecStart=/home/terraform/scripts/start.sh
Environment=PYTHONUNBUFFERED=1
Restart=always

[Install]
WantedBy=multi-user.target
EOF
