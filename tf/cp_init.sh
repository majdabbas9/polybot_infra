#!/bin/bash
set -euxo pipefail
set -x

MARKER_FILE="/var/local/cluster-init.done"
if [ -f "$MARKER_FILE" ]; then
  echo "Cluster init script already ran, exiting."
  exit 0
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

READY_WORKERS=$(kubectl get nodes --no-headers 2>/dev/null | grep -v master | grep -v control-plane | grep -c " Ready")
if [ "$READY_WORKERS" -lt 1 ]; then
  echo "❌ Timeout waiting for worker node to join."
  exit 1
fi

# Install Calico if not installed
if ! kubectl get pods -n kube-system | grep calico >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
else
  echo "Calico already installed, skipping."
fi

# Install NGINX Ingress Controller if not installed
if ! kubectl get pods -n ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/baremetal/deploy.yaml
else
  echo "NGINX Ingress already installed, skipping."
fi

# Argo CD Helm install vars
NAMESPACE="argocd"
RELEASE_NAME="argocd"
ARGOCD_HELM_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_HELM_CHART="argo-cd"

INGRESS_NAMESPACE="ingress-nginx"
INGRESS_RELEASE="nginx-ingress"
HTTP_PORT=31080
HTTPS_PORT=30001

# Create Argo CD Namespace if needed
if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "🔧 Creating namespace $NAMESPACE..."
  kubectl create namespace "$NAMESPACE"
else
  echo "✅ Namespace $NAMESPACE already exists."
fi

# Install Helm if missing
if ! command -v helm &> /dev/null; then
  echo "❌ Helm not found. Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm is already installed."
fi

echo "🔍 Verifying Helm version..."
helm version

# Add Helm repos
echo "📦 Adding Argo CD and Ingress-NGINX Helm repositories..."
helm repo add argo "$ARGOCD_HELM_REPO" || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true

echo "🔄 Updating Helm repositories..."
helm repo update

# Install Argo CD Helm chart
if ! helm status "$RELEASE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "🚀 Installing Argo CD via Helm into namespace $NAMESPACE..."
  helm install "$RELEASE_NAME" argo/"$ARGOCD_HELM_CHART" -n "$NAMESPACE"
else
  echo "✅ Argo CD Helm release '$RELEASE_NAME' already exists in namespace $NAMESPACE."
fi

# Install Ingress NGINX Helm chart
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

# Mark the script as done so it does not run twice
touch "$MARKER_FILE"
echo "Cluster init script completed successfully."
