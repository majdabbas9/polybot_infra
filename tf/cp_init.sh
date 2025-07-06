#!/bin/bash
set -eux

#!/bin/bash

# Check if helm is installed
if ! command -v helm &> /dev/null; then
  echo "Helm not found, installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Helm is already installed."
fi

# Verify helm installation
helm version

# Add ingress-nginx repo
echo "Adding ingress-nginx Helm repo..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update Helm repos
echo "Updating Helm repos..."
helm repo update

# Install nginx ingress with NodePort 31080 (HTTP) and 30001 (HTTPS)
echo "Installing nginx ingress controller..."
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=31080 \
  --set controller.service.nodePorts.https=30001

echo "Done!"
# ✅ Exit early if control plane is already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "[INFO] Kubernetes control plane already initialized. Exiting."
  exit 0
fi

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
sleep 120
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

NAMESPACE="argocd"
ARGOCD_DEPLOYMENT="argocd-server"
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Step 1: Create the namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "🔧 Creating namespace $NAMESPACE..."
  kubectl create namespace "$NAMESPACE"
else
  echo "✅ Namespace $NAMESPACE already exists."
fi

# Step 2: Check if Argo CD is already installed (based on a known deployment)
if ! kubectl get deployment "$ARGOCD_DEPLOYMENT" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "🚀 Installing Argo CD in $NAMESPACE..."
  kubectl apply -n "$NAMESPACE" -f "$MANIFEST_URL"
else
  echo "✅ Argo CD is already installed in $NAMESPACE."
fi

