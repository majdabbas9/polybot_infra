#!/bin/bash
set -euo pipefail
set -x
# ✅ Exit early if control plane is already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "[INFO] Kubernetes control plane already initialized. Exiting."
  exit 0
fi

# Run directly on the EC2 control plane — no SSH inside
for i in {1..60}; do
  if command -v kubeadm >/dev/null 2>&1; then
    echo "kubeadm found!"
    break
  else
    echo "Waiting for kubeadm to be installed... ($i/60)"
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

# Wait for at least one Ready worker node (not the control plane)
for i in {1..60}; do  # 10 minutes max (60 * 10s)
  READY_WORKERS=$(kubectl get nodes --no-headers 2>/dev/null | grep -v master | grep -v control-plane | grep -c " Ready")
  if [ "$READY_WORKERS" -ge 1 ]; then
    echo "✅ Worker node joined and is Ready!"
    break
  else
    echo "⏳ Waiting for a worker node to join... ($i/60)"
    sleep 10
  fi
done

# Check again in case of timeout
READY_WORKERS=$(kubectl get nodes --no-headers 2>/dev/null | grep -v master | grep -v control-plane | grep -c " Ready")
if [ "$READY_WORKERS" -lt 1 ]; then
  echo "❌ Timeout waiting for worker node to join."
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

# -------------------------------
# Argo CD Helm Installation Vars
# -------------------------------
NAMESPACE="argocd"
RELEASE_NAME="argocd"
ARGOCD_HELM_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_HELM_CHART="argo-cd"

# -------------------------------
# Ingress-NGINX Installation Vars
# -------------------------------
INGRESS_NAMESPACE="ingress-nginx"
INGRESS_RELEASE="nginx-ingress"
HTTP_PORT=31080
HTTPS_PORT=30001

# -------------------------------
# Step 1: Create Argo CD Namespace
# -------------------------------
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "🔧 Creating namespace $NAMESPACE..."
  kubectl create namespace "$NAMESPACE"
else
  echo "✅ Namespace $NAMESPACE already exists."
fi

# -------------------------------
# Step 2: Check and Install Helm
# -------------------------------
if ! command -v helm &> /dev/null; then
  echo "❌ Helm not found. Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm is already installed."
fi

# Verify Helm installation
echo "🔍 Verifying Helm version..."
helm version

# -------------------------------
# Step 3: Add and Update Helm Repos
# -------------------------------
echo "📦 Adding Argo CD and Ingress-NGINX Helm repositories..."
helm repo add argo "$ARGOCD_HELM_REPO" || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true

echo "🔄 Updating Helm repositories..."
helm repo update

# -------------------------------
# Step 4: Install Argo CD
# -------------------------------
if ! helm status "$RELEASE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "🚀 Installing Argo CD via Helm into namespace $NAMESPACE..."
  helm install "$RELEASE_NAME" argo/"$ARGOCD_HELM_CHART" -n "$NAMESPACE"
else
  echo "✅ Argo CD Helm release '$RELEASE_NAME' already exists in namespace $NAMESPACE."
fi

# -------------------------------
# Step 5: Install Ingress-NGINX with NodePorts
# -------------------------------
if ! helm status "$INGRESS_RELEASE" -n "$INGRESS_NAMESPACE" > /dev/null 2>&1; then
  echo "🌐 Installing Ingress-NGINX controller on NodePorts $HTTP_PORT/$HTTPS_PORT..."
  helm install "$INGRESS_RELEASE" ingress-nginx/ingress-nginx \
    --namespace "$INGRESS_NAMESPACE" --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http="$HTTP_PORT" \
    --set controller.service.nodePorts.https="$HTTPS_PORT"
else
  echo "✅ Ingress-NGINX Helm release '$INGRESS_RELEASE' already exists in namespace $INGRESS_NAMESPACE."
fi

