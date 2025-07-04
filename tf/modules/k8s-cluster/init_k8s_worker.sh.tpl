#!/bin/bash
exec > /var/log/worker-init.log 2>&1
set -e

# Install prerequisites
apt-get update
apt-get install -y curl jq unzip ebtables ethtool gpg

# Install AWS CLI v2
curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update

# Enable IP forwarding
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sysctl --system

# Install CRI-O and Kubernetes
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Start services
systemctl start crio
systemctl enable crio
systemctl enable kubelet

# Disable swap (required by Kubernetes)
swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# Install and start Amazon SSM Agent
curl -O https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable --now amazon-ssm-agent

# Fetch kubeadm join command from SSM
JOIN_CMD=$(aws ssm get-parameter \
  --name "/k8s/worker/join-command-majd" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "eu-west-1")

sudo $JOIN_CMD

