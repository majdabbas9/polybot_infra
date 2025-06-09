#!/bin/bash
set -e

REPO_DIR=$1
NGINX_CONF_SRC="$REPO_DIR/Nginx/default.conf"
export NGINX_CONF_DST="$HOME/conf.d"
export CERTS_DIR="$HOME/certs"

echo "📁 Preparing Nginx configuration and certs..."

# Create config and certs directories
mkdir -p "$NGINX_CONF_DST"
mkdir -p "$CERTS_DIR"

echo "📥 Writing certs to $CERTS_DIR"
printf "%s" "$APP_CERT" > "$CERTS_DIR/poly-prod.crt"
printf "%s" "$APP_KEY" > "$CERTS_DIR/poly-prod.key"
printf "%s" "$APP_DEV_CERT" > "$CERTS_DIR/poly-dev.crt"
printf "%s" "$APP_DEV_KEY" > "$CERTS_DIR/poly-dev.key"

# Copy Nginx config
cp "$NGINX_CONF_SRC" "$NGINX_CONF_DST/default.conf"

echo "🚢 Deploying Nginx container..."

sudo docker compose -f docker-compose.dev.yaml down
sudo docker compose -f docker-compose.nginx.yaml up -d

echo "✅ Nginx container deployed with HTTPS support!"