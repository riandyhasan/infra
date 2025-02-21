#!/bin/bash
set -eo pipefail

# Configuration
NGINX_CONF="/etc/nginx/conf.d/load-balancer.conf"
SERVICE_NAME="backend"
LOG_FILE="./deploy.log"

# Initialize logging
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to get current mapped ports
get_active_ports() {
  docker-compose ps $SERVICE_NAME | grep 'Up' | awk '{print $NF}' | 
  awk -F'->' '{print $1}' | cut -d':' -f2 | sort -u
}

# 1. Start new containers alongside old ones
echo "Deploying new containers..."
docker-compose up -d --build --scale $SERVICE_NAME=+1 --no-recreate

# 2. Wait for new containers to become healthy
echo "Waiting for new containers to stabilize..."
NEW_PORTS=$(get_active_ports)
for port in $NEW_PORTS; do
  while ! curl -sf "http://127.0.0.1:$port/health" >/dev/null; do
    sleep 2
  done
  echo "Port $port healthy"
done

# 3. First Nginx update with all ports
echo "Updating Nginx with all active ports..."
sudo cp "$NGINX_CONF" "${NGINX_CONF}.bak"
sudo tee "$NGINX_CONF" >/dev/null <<EOF
upstream backend {
    least_conn;
    $(for port in $NEW_PORTS; do echo "    server 127.0.0.1:$port;"; done)
}

server {
    listen 80;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
EOF

# 4. Gracefully reload Nginx
echo "First Nginx reload..."
sudo nginx -t && sudo systemctl reload nginx

# 5. Scale down to original size
echo "Removing old containers..."
docker-compose up -d --scale $SERVICE_NAME=$(docker-compose config --services | 
  xargs -I{} docker-compose ps -q {} | wc -l | awk '{print $1-1}')

# 6. Final Nginx update after scale down
FINAL_PORTS=$(get_active_ports)
echo "Final Nginx update with remaining ports: $FINAL_PORTS"
sudo tee "$NGINX_CONF" >/dev/null <<EOF
upstream backend {
    least_conn;
    $(for port in $FINAL_PORTS; do echo "    server 127.0.0.1:$port;"; done)
}

server {
    listen 80;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
EOF

# 7. Final Nginx reload
echo "Final Nginx reload..."
sudo nginx -t && sudo systemctl reload nginx

echo "Deployment complete!"