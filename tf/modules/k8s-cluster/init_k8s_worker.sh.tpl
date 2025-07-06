#!/bin/bash
# Log everything for debugging
exec > /var/log/worker-init.log 2>&1
set -euxo pipefail

# --- Step 1: Update system and install prerequisites ---
apt-get update
apt-get install -y curl jq unzip ebtables ethtool gpg apt-transport-https ca-certificates software-properties-common

# --- Step 2: Install AWS CLI v2 ---
curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update

# --- Step 3: Enable IP forwarding ---
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/k8s.conf
sysctl --system

# --- Step 4: Add Kubernetes + CRI-O Repositories ---
mkdir -p /etc/apt/keyrings

# ✅ Use Kubernetes v1.29 (v1.32 doesn't exist yet)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

# CRI-O (Optional: use only if needed)
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

# --- Step 5: Install Kubernetes and CRI-O ---
apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- Step 6: Start and enable services ---
systemctl enable --now crio
systemctl enable --now kubelet

sudo apt install -y snapd
sudo snap install amazon-ssm-agent --classic
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf

echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Join the worker node to the Kubernetes cluster
echo "[INFO] Waiting for AWS metadata service..."
until curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/iam/security-credentials/; do
  sleep 2
done

echo "[INFO] Ensuring AWS CLI is in PATH..."
export PATH=$PATH:/usr/local/bin
sleep 240
for i in {1..5}; do
  echo "[INFO] Attempt $i: Fetching join command from SSM..."
  JOIN_CMD=$(/usr/local/bin/aws ssm get-parameter \
    --name "/k8s/worker/join-command-majd" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text \
    --region "eu-west-1") && break
  sleep 5
done

if [ -z "$JOIN_CMD" ]; then
  echo "[ERROR] Failed to fetch join command after 5 attempts" >&2
  exit 1
fi

echo "[INFO] Running join command..."
sudo $JOIN_CMD

# --- Step 7: Disable swap (required by Kubernetes) ---
swapoff -a
(crontab -l 2>/dev/null || true; echo "@reboot /sbin/swapoff -a") | crontab -



