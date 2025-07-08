#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -eux

KUBERNETES_VERSION=v1.32

echo "Reached k1" >> /var/log/k.txt

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <TELEGRAM_TOKEN_DEV> <TELEGRAM_TOKEN> <DEV_BUCKET_ID> <PROD_BUCKET_ID> <DEV_SQS_URL> <PROD_SQS_URL>"
  exit 1
fi

TELEGRAM_TOKEN_DEV="$1"
TELEGRAM_TOKEN="$2"
DEV_BUCKET_ID="$3"
PROD_BUCKET_ID="$4"
DEV_SQS_URL="$5"
PROD_SQS_URL="$6"

# Create or update the k8s secret named "my-secrets"
kubectl delete secret my-secrets --ignore-not-found

kubectl create secret generic my-secrets \
  --from-literal=TELEGRAM_TOKEN_DEV="$TELEGRAM_TOKEN_DEV" \
  --from-literal=TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
  --from-literal=DEV_BUCKET_ID="$DEV_BUCKET_ID" \
  --from-literal=PROD_BUCKET_ID="$PROD_BUCKET_ID" \
  --from-literal=DEV_SQS_URL="$DEV_SQS_URL" \
  --from-literal=PROD_SQS_URL="$PROD_SQS_URL"

apt-get update
apt-get install -y jq unzip ebtables ethtool curl software-properties-common apt-transport-https ca-certificates gpg

echo "Reached k2" >> /var/log/k.txt

# install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update

echo "Reached k3" >> /var/log/k.txt

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo "Reached k4" >> /var/log/k.txt

# Install Kubernetes & CRI-O
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "Reached k5" >> /var/log/k.txt

systemctl start crio
systemctl enable --now crio
systemctl enable --now kubelet

swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

echo "Finished successfully" >> /var/log/k.txt