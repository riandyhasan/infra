#!/bin/bash
set -eo pipefail

# Configuration
REPLICA_COUNT=3
NGINX_CONFIG="/etc/nginx/sites-available/api.com"
SERVICE_NAME="backend"
TEMPORARY_SCALE=$((REPLICA_COUNT * 2))

# Get current containers before scaling
PREVIOUS_CONTAINERS=$(docker-compose ps -q ${SERVICE_NAME})

# Scale up new instances
echo "Scaling up to ${TEMPORARY_SCALE} instances..."
docker-compose up -d --scale ${SERVICE_NAME}=${TEMPORARY_SCALE} --no-recreate

# Wait for new containers to initialize
echo "Waiting for new containers to start..."
sleep 10  # Reduced from 100s to 10s, but consider health checks

# Get updated container list
ALL_CONTAINERS=$(docker-compose ps -q ${SERVICE_NAME})

# Identify new containers (those not in previous list)
NEW_CONTAINERS=$(comm -23 <(echo "${ALL_CONTAINERS}" | sort) <(echo "${PREVIOUS_CONTAINERS}" | sort))

# Get ports for new containers
NEW_PORTS=$(echo "${NEW_CONTAINERS}" | xargs -n1 docker inspect --format='{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}')

# Update Nginx configuration
echo "Updating Nginx upstream..."
sudo cp "${NGINX_CONFIG}" "${NGINX_CONFIG}.bak"

UPSTREAM_BLOCK="upstream backend {"
for port in ${NEW_PORTS}; do
    UPSTREAM_BLOCK+="\n    server 127.0.0.1:${port};"
done
UPSTREAM_BLOCK+="\n}"

sudo perl -i -pe "BEGIN{undef $/;} s/upstream backend \{.*?\}/$(echo -e ${UPSTREAM_BLOCK})/smg" "${NGINX_CONFIG}"

# Validate and reload Nginx
sudo nginx -t && sudo nginx -s reload

# Gracefully remove old containers
echo "Removing previous containers..."
if [ -n "${PREVIOUS_CONTAINERS}" ]; then
    echo "Stopping containers: ${PREVIOUS_CONTAINERS}"
    docker kill -s SIGTERM ${PREVIOUS_CONTAINERS} || true
    sleep 5  # Wait for graceful shutdown
    docker rm -f ${PREVIOUS_CONTAINERS} || true
fi

# Final scale adjustment
echo "Ensuring correct replica count..."
docker-compose up -d --scale ${SERVICE_NAME}=${REPLICA_COUNT}

echo "Rollout complete! New active ports:"
echo "${NEW_PORTS}"