#!/bin/bash

# Define variables
CONTAINER_NAME="myprometheus"
#CONFIG_DIR="./Prometheus"
#PROMETHEUS_YML="$CONFIG_DIR/Prometheus.yml"

# Ensure the config file exists
#if [ ! -f "$PROMETHEUS_YML" ]; then
#  echo "❌ prometheus.yml not found in $CONFIG_DIR"
#  exit 1
#fi

# Pull Prometheus image
echo "⬇ Pulling Prometheus image..."
docker pull prom/prometheus

# Stop and remove existing container
echo "🧹 Cleaning up old Prometheus container (if any)..."
docker rm -f $CONTAINER_NAME 2>/dev/null

## Run Prometheus container with mounted config
#echo "🚀 Starting Prometheus container..."
#docker run -d \
#  --name $CONTAINER_NAME \
#  -p 9090:9090 \
#  -v "$(pwd)/prometheus:/etc/prometheus" \
#  prom/prometheus \
#  --config.file=/etc/Prometheus/Prometheus.yml
#
#echo "✅ Prometheus is running at http://localhost:9090"
