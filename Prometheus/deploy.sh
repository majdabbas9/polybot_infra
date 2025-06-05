#!/bin/bash

# Define variables
PROMETHEUS_YML_PATH=$1

# Pull Prometheus image
echo "⬇ Pulling Prometheus image..."
sudo docker pull prom/prometheus

# Stop and remove existing container
echo "🧹 Checking for old Prometheus container..."

if sudo docker ps -a --format '{{.Names}}' | grep -q '^myprometheus$'; then
  echo "🧹 Removing old container 'myprometheus'..."
  sudo docker rm -f myprometheus
else
  echo "✅ No existing container named 'myprometheus' found."
fi

## Run Prometheus container with mounted config
echo "🚀 Starting Prometheus container..."
sudo docker run \
  --name myprometheus -d \
  -p 0.0.0.0:9090:9090 \
  -v PROMETHEUS_YML_PATH:/etc/prometheus/prometheus.yml \
  prom/prometheus

echo "✅ Prometheus is running at http://localhost:9090"
