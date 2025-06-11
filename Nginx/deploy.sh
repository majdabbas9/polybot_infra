#!/bin/bash
set -e

NGINX_CONF_SRC="$HOME/Nginx/default.conf"
NGINX_CONF_DST="$HOME/conf.d"
CERTS_DIR="$HOME/certs"

echo "📁 Preparing Nginx configuration and certs..."

# Create config and certs directories
mkdir -p "$NGINX_CONF_DST"
mkdir -p "$CERTS_DIR"

echo "📥 Writing certs to $CERTS_DIR"
printf "%s" "$APP_CERT" > "$CERTS_DIR/poly-prod.crt"
printf "%s" "$APP_KEY" > "$CERTS_DIR/poly-prod.key"
printf "%s" "$APP_DEV_CERT" > "$CERTS_DIR/poly-dev.crt"
printf "%s" "$APP_DEV_KEY" > "$CERTS_DIR/poly-dev.key"

echo "🚢 Deploying Nginx container..."

ENV_FILE="$HOME/docker-compose-files/.env"
cat > "$ENV_FILE" <<EOF
NGINX_CONF_DST=$NGINX_CONF_DST
CERTS_DIR=$CERTS_DIR
EOF

sudo docker compose -f docker-compose-files/docker-compose.nginx.yaml down
sudo docker compose -f docker-compose-files/docker-compose.nginx.yaml up -d

echo "✅ Nginx container deployed with HTTPS support!"