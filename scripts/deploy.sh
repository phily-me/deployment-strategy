#!/bin/bash
set -e

# Deployment script for Python uv project
# Usage: deploy.sh <image_tag> <project_name> <git_branch> <subdomain>

IMAGE_TAG="$1"
PROJECT_NAME="$2"
GIT_BRANCH="$3"
SUBDOMAIN="$4"

if [ -z "$IMAGE_TAG" ] || [ -z "$PROJECT_NAME" ] || [ -z "$GIT_BRANCH" ] || [ -z "$SUBDOMAIN" ]; then
    echo "Usage: $0 <image_tag> <project_name> <git_branch> <subdomain>"
    exit 1
fi

echo "=== Starting deployment for $IMAGE_TAG ==="

# Configuration
CONTAINER_NAME="${PROJECT_NAME}-${GIT_BRANCH}"
DOCKER_COMPOSE_FILE="/tmp/docker-compose-${PROJECT_NAME}-${GIT_BRANCH}.yml"
NGINX_CONFIG_FILE="/tmp/nginx-${PROJECT_NAME}-${GIT_BRANCH}.conf"
IMAGE_ARCHIVE="/tmp/${IMAGE_TAG}.tar.gz"

# Find available port
find_available_port() {
    local start_port=8080
    local max_port=9000
    
    for port in $(seq $start_port $max_port); do
        if ! netstat -tuln | grep -q ":$port "; then
            echo $port
            return
        fi
    done
    
    echo "No available ports found between $start_port and $max_port"
    exit 1
}

CONTAINER_PORT=$(find_available_port)
echo "Using port: $CONTAINER_PORT"

# Stop and remove existing container
echo "=== Stopping existing container ==="
docker-compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Load new Docker image
echo "=== Loading Docker image ==="
gunzip -c "$IMAGE_ARCHIVE" | docker load

# Update docker-compose file with port
echo "=== Updating docker-compose configuration ==="
export container_port="$CONTAINER_PORT"
envsubst < "$DOCKER_COMPOSE_FILE" > "/tmp/docker-compose-${PROJECT_NAME}-${GIT_BRANCH}-final.yml"

# Start new container
echo "=== Starting new container ==="
docker-compose -f "/tmp/docker-compose-${PROJECT_NAME}-${GIT_BRANCH}-final.yml" up -d

# Wait for container to be healthy
echo "=== Waiting for container to be healthy ==="
for i in {1..30}; do
    if docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' | grep -q healthy; then
        echo "Container is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Container failed to become healthy"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    sleep 2
done

# Get container IP address
echo "=== Getting container IP address ==="
CONTAINER_IP=$(docker inspect "$CONTAINER_NAME" --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "Container IP: $CONTAINER_IP"

# Setup nginx proxy manager entry
echo "=== Setting up nginx proxy manager ==="
if [ -f "/tmp/setup-npm.sh" ]; then
    bash /tmp/setup-npm.sh "$SUBDOMAIN" "$CONTAINER_IP" "$CONTAINER_PORT"
else
    echo "Warning: nginx proxy manager setup script not found"
    echo "You will need to manually configure the proxy for $SUBDOMAIN -> $CONTAINER_IP:$CONTAINER_PORT"
fi

# Clean up temporary files
echo "=== Cleaning up temporary files ==="
rm -f "$IMAGE_ARCHIVE" "$DOCKER_COMPOSE_FILE"
rm -f "/tmp/docker-compose-${PROJECT_NAME}-${GIT_BRANCH}-final.yml"
rm -f "/tmp/setup-npm.sh"

echo "=== Deployment completed successfully ==="
echo "Application is available at: https://$SUBDOMAIN"
echo "Container port: $CONTAINER_PORT"
echo "Container name: $CONTAINER_NAME"