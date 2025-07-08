#!/bin/bash
exec > >(tee -a setup.log) 2>&1
set -euxo pipefail

for ns in dev prod argocd ingress-nginx; do
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "Creating namespace $ns"
    kubectl create namespace "$ns"
  else
    echo "Namespace $ns already exists, skipping."
  fi
done

# Create secret in dev namespace
# Check if secret exists in dev namespace
if kubectl get secret my-secrets-dev --namespace=dev > /dev/null 2>&1; then
  echo "Secret my-secrets-dev already exists in dev namespace"
else
  kubectl create secret generic my-secrets-dev \
    --namespace=dev \
    --from-literal=TELEGRAM_TOKEN_DEV="$TELEGRAM_TOKEN_DEV" \
    --from-literal=DEV_BUCKET_ID="$DEV_BUCKET_ID" \
    --from-literal=DEV_SQS_URL="$DEV_SQS_URL"
fi

# Check if secret exists in prod namespace
if kubectl get secret my-secrets-prod --namespace=prod > /dev/null 2>&1; then
  echo "Secret my-secrets-prod already exists in prod namespace"
else
  kubectl create secret generic my-secrets-prod \
    --namespace=prod \
    --from-literal=TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
    --from-literal=PROD_BUCKET_ID="$PROD_BUCKET_ID" \
    --from-literal=PROD_SQS_URL="$PROD_SQS_URL"
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

HTTP_PORT=31080
HTTPS_PORT=30001

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
# helm repo add argo "$ARGOCD_HELM_REPO" || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true

echo "🔄 Updating Helm repositories..."
helm repo update

if ! helm status argocd -n argocd > /dev/null 2>&1; then
  echo "🚀 Installing Argo CD via Helm into namespace argocd..."
  helm install argocd argo/argo-cd --namespace argocd \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp="$HTTP_PORT" \
    --set server.service.nodePortHttps="$HTTPS_PORT"
else
  echo "✅ Argo CD Helm release 'argocd' already exists in namespace argocd."
fi

# Install Ingress NGINX Helm chart
if ! helm status "ingress-nginx" -n "ingress-nginx" > /dev/null 2>&1; then
  echo "🌐 Installing Ingress-NGINX controller on NodePorts $HTTP_PORT/$HTTPS_PORT..."
  helm install "ingress-nginx" ingress-nginx/ingress-nginx \
    --namespace "ingress-nginx" --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http="$HTTP_PORT" \
    --set controller.service.nodePorts.https="$HTTPS_PORT"
else
  echo "✅ Ingress-NGINX Helm release 'ingress-nginx' already exists in namespace ingress-nginx."
fi

