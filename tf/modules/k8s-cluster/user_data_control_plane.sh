#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -eux

KUBERNETES_VERSION=v1.32

echo "Reached k1" >> /var/log/k.txt

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