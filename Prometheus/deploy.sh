#!/bin/bash

# Define variables
REPO_NAME=$1

# Pull Prometheus image
## Run Prometheus container with mounted config
echo "🚀 Starting Prometheus container..."
ENV_FILE="./.env"
cat > "$ENV_FILE" <<EOF
PROMETHEUS_CONFIG=~/$REPO_NAME/Prometheus/prometheus.yml
EOF

sudo docker compose -f docker-compose.prometheus.yaml down
sudo docker compose -f docker-compose.prometheus.yaml up -d

echo "✅ Prometheus is running at http://localhost:9090"
