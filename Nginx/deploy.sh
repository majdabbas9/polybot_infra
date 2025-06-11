#!/bin/bash
set -e

WORKing_DIR="$HOME/Nginx"

NGINX_CONF_SRC="$WORKing_DIR/default.conf"
CERTS_DIR="$WORKing_DIR/certs"

echo "📁 Preparing Nginx configuration and certs..."

# Create config and certs directories
mkdir -p "$CERTS_DIR"

echo "📥 Writing certs to $CERTS_DIR"
printf "%s" "$APP_CERT" > "$CERTS_DIR/poly-prod.crt"
printf "%s" "$APP_KEY" > "$CERTS_DIR/poly-prod.key"
printf "%s" "$APP_DEV_CERT" > "$CERTS_DIR/poly-dev.crt"
printf "%s" "$APP_DEV_KEY" > "$CERTS_DIR/poly-dev.key"
echo "🚢 Deploying Nginx container..."

ENV_FILE="$WORKing_DIR/.env"
cat > "$ENV_FILE" <<EOF
NGINX_CONF_DST=$NGINX_CONF_SRC
CERTS_DIR=$CERTS_DIR
EOF

sudo docker compose -f docker-compose.nginx.yaml down
sudo docker compose -f docker-compose.nginx.yaml up -d

echo "✅ Nginx container deployed with HTTPS support!"