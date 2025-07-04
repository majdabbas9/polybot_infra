#!/bin/bash
set -eux

# Run directly on the EC2 control plane — no SSH inside

if [ ! -f /etc/kubernetes/admin.conf ]; then
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # ✅ Generate and push the join command to SSM
  JOIN_CMD=$(kubeadm token create --print-join-command)
  aws ssm put-parameter \
    --name "/k8s/worker/join-command-majd" \
    --type "SecureString" \
    --value "$JOIN_CMD" \
    --overwrite \
    --region "eu-west-1"

else
  echo "Control plane already initialized, skipping kubeadm init."
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