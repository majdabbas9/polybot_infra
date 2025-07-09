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
if kubectl get secret ghcr-secret >/dev/null 2>&1; then
  echo "Secret ghcr-secret exists"
else
  kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=majdabbas9 \
  --docker-password=$GITHUB_PAT \
  --docker-email=majd.abbas999@gmail.com
fi

# Create secret in dev namespace
# Check if secret exists in dev namespace
if kubectl get secret my-secrets-dev --namespace=dev > /dev/null 2>&1; then
  echo "Secret my-secrets-dev already exists in dev namespace"
else
  kubectl create secret generic my-secrets-dev \
    --namespace=dev \
    --from-literal=TELEGRAM_TOKEN="$TELEGRAM_TOKEN_DEV" \
    --from-literal=BUCKET_ID="$DEV_BUCKET_ID" \
    --from-literal=SQS_URL="$DEV_SQS_URL"
fi

# Check if secret exists in prod namespace
if kubectl get secret my-secrets-prod --namespace=prod > /dev/null 2>&1; then
  echo "Secret my-secrets-prod already exists in prod namespace"
else
  kubectl create secret generic my-secrets-prod \
    --namespace=prod \
    --from-literal=TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
    --from-literal=BUCKET_ID="$PROD_BUCKET_ID" \
    --from-literal=SQS_URL="$PROD_SQS_URL"
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
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo add argo https://argoproj.github.io/argo-helm || true

echo "🔄 Updating Helm repositories..."
helm repo update

 Check and install Argo CD Helm release
if helm list -n argocd | grep -qw argocd; then
  echo "Argo CD Helm release 'argocd' already exists in 'argocd', skipping."
else
  echo "Installing Argo CD Helm release 'argocd'..."
  helm install argocd argo/argo-cd --namespace argocd
fi

# Install Ingress NGINX Helm chart
if helm list -n ingress-nginx | grep -qw ingress-nginx; then
  echo "Ingress-NGINX Helm release 'ingress-nginx' already exists, skipping."
else
  echo "Installing Ingress-NGINX Helm release 'ingress-nginx'..."
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http="$HTTP_PORT" \
    --set controller.service.nodePorts.https="$HTTPS_PORT"
fi

