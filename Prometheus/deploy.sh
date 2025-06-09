#!/bin/bash

# Define variables
REPO_NAME=$1

echo "🚀 Starting Prometheus container..."
ENV_FILE="./.env"
cat > "$ENV_FILE" <<EOF
PROMETHEUS_CONFIG=$HOME/$REPO_NAME/Prometheus/prometheus.yml
EOF

sudo docker compose -f docker-compose.prometheus.yaml down
sudo docker compose -f docker-compose.prometheus.yaml up -d

echo "✅ Prometheus is running at http://localhost:9090"
