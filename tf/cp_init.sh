#!/bin/bash
set -eux

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