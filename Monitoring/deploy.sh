#!/bin/bash

# Define variables
WORKing_DIR="$HOME/Monitoring"

echo "🚀 Starting Monitoring containers..."
ENV_FILE="$WORKing_DIR/.env"
cat > "$ENV_FILE" <<EOF
PROMETHEUS_CONFIG=$WORKing_DIR/prometheus.yml
EOF

sudo docker compose -f docker-compose.monitoring.yaml down
sudo docker compose -f docker-compose.monitoring.yaml up -d

echo "✅ Prometheus is running at http://localhost:9090"
echo "✅ Grafana is running at http://localhost:3000"
