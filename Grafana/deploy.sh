sudo docker pull grafana/grafana

# Stop and remove existing container
echo "🧹 Checking for old Grafana container..."

if sudo docker ps -a --format '{{.Names}}' | grep -q '^mygrafana'; then
  echo "🧹 Removing old container 'mygrafana'..."
  sudo docker rm -f mygrafana
else
  echo "✅ No existing container named 'mygrafana' found."
fi

sudo docker run \
  --name=mygrafana -d \
  -p 3000:3000 grafana/grafana
