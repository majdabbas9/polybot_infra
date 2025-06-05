#!/bin/bash

# Define variables
CONTAINER_NAME="myprometheus"
PROMETHEUS_YML_PATH=$1

# Pull Prometheus image
echo "⬇ Pulling Prometheus image..."
sudo docker pull prom/prometheus

# Stop and remove existing container
echo "🧹 Cleaning up old Prometheus container (if any)..."
sudo docker rm -f $CONTAINER_NAME 2>/dev/null

## Run Prometheus container with mounted config
echo "🚀 Starting Prometheus container..."
sudo docker run \
  --name $CONTAINER_NAME -d \
  -p 127.0.0.1:9090:9090 \
  -v PROMETHEUS_YML_PATH:/etc/prometheus/prometheus.yml \
  prom/prometheus

echo "✅ Prometheus is running at http://localhost:9090"
