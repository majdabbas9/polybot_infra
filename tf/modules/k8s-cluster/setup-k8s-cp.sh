#!/bin/bash
KUBERNETES_VERSION=v1.32

apt-get update
apt-get install -y jq unzip ebtables ethtool

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/k8s.conf
sysctl --system

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${KUBERNETES_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" > /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
apt-get install -y cri-o kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl start crio.service
systemctl enable --now crio.service
systemctl enable --now kubelet

swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -