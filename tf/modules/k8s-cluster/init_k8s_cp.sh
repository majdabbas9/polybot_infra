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

# Run directly on the EC2 control plane — no SSH inside
for i in {1..30}; do
  if command -v kubeadm >/dev/null 2>&1; then
    echo "kubeadm found!"
    break
  else
    echo "Waiting for kubeadm to be installed... ($i/30)"
    sleep 5
  fi
done

while [ ! -f /etc/kubernetes/admin.conf ]; do
  echo "[INFO] /etc/kubernetes/admin.conf not found, trying kubeadm init..."

  if sudo kubeadm init --pod-network-cidr=192.168.0.0/16; then
    echo "[INFO] kubeadm init succeeded."

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Generate and push the join command to SSM
    JOIN_CMD=$(kubeadm token create --print-join-command)
    aws ssm put-parameter \
      --name "/k8s/worker/join-command-majd" \
      --type "SecureString" \
      --value "$JOIN_CMD" \
      --overwrite \
      --region "eu-west-1"

    break  # Exit the loop on success
  else
    echo "[WARN] kubeadm init failed, retrying in 10 seconds..."
    sleep 10
  fi
done

if [ -f /etc/kubernetes/admin.conf ]; then
  echo "Control plane already initialized or successfully initialized now."
else
  echo "Failed to initialize control plane after retries."
  exit 1
fi


# ✅ Install Calico if not already present
if ! kubectl get pods -n kube-system | grep calico >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
else
  echo "Calico already installed, skipping."
fi

# ✅ Install NGINX Ingress Controller if not already present
if ! kubectl get pods -n ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/baremetal/deploy.yaml
else
  echo "NGINX Ingress already installed, skipping."
fi

# Disable swap
swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

echo "Finished successfully" >> /var/log/k.txt