#!/bin/bash

# Docker development environment setup script
# Builds Docker image, starts container, and creates command wrappers

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source environment variables
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Find an available port in the specified range
find_available_port() {
    local start_port="${DEV_PORT_START:-8000}"
    local end_port="${DEV_PORT_END:-8099}"
    
    for port in $(seq $start_port $end_port); do
        if ! lsof -i:$port >/dev/null 2>&1; then
            echo $port
            return 0
        fi
    done
    
    log_error "No available ports found in range $start_port-$end_port"
    return 1
}

# Build development Docker image if it doesn't exist
build_dev_image() {
    local project_root="$1"
    
    if ! docker images | grep -q "$DEV_IMAGE_NAME"; then
        log_info "Building development Docker image: $DEV_IMAGE_NAME"
        docker build -f "$project_root/$DEV_DOCKERFILE" -t "$DEV_IMAGE_NAME" "$project_root"
    else
        log_debug "Development image $DEV_IMAGE_NAME already exists"
    fi
}

# Start development container if not running
start_dev_container() {
    local project_root="$1"
    
    if ! docker ps | grep -q "$DEV_CONTAINER_NAME"; then
        log_info "Starting development container: $DEV_CONTAINER_NAME"
        
        # Stop and remove existing container if it exists but is not running
        if docker ps -a | grep -q "$DEV_CONTAINER_NAME"; then
            log_debug "Removing existing stopped container"
            docker rm "$DEV_CONTAINER_NAME" >/dev/null 2>&1 || true
        fi
        
        # Find available port
        local host_port
        if ! host_port=$(find_available_port); then
            return 1
        fi
        
        log_info "Using port $host_port for development server"
        
        docker run -d \
            --name "$DEV_CONTAINER_NAME" \
            --rm \
            -v "$project_root:/workspace" \
            -v "$DOCKER_SOCKET_PATH:$DOCKER_SOCKET_PATH" \
            -w "/workspace" \
            -p "$host_port:8000" \
            --env "PROJECT_NAME=$PROJECT_NAME" \
            --env "DOMAIN_SUFFIX=$DOMAIN_SUFFIX" \
            "$DEV_IMAGE_NAME"
        
        # Store the port for later reference
        echo "$host_port" > "$project_root/.dev-port"
        
        # Fix git worktree issue if present
        if [[ -f "$project_root/.git" ]] && grep -q "gitdir:" "$project_root/.git" 2>/dev/null; then
            log_warn "Git worktree detected - initializing proper git repo in container"
            docker exec "$DEV_CONTAINER_NAME" bash -c "
                cd /workspace && 
                rm -f .git && 
                git init . && 
                git config user.email 'dev@container.local' && 
                git config user.name 'Dev Container' && 
                git add . && 
                git commit -m 'Container initialization' >/dev/null 2>&1 || true
            "
        fi
    else
        log_debug "Development container $DEV_CONTAINER_NAME is already running"
    fi
}

# No longer needed - users will just exec into the container directly

# Main setup function
setup_docker_dev() {
    local project_root="$1"
    
    cd "$project_root"
    
    # Build image if needed
    build_dev_image "$project_root"
    
    # Start container
    start_dev_container "$project_root"
    
    # Get the port being used
    local port=""
    if [[ -f "$project_root/.dev-port" ]]; then
        port=$(cat "$project_root/.dev-port")
    fi
    
    log_info "Docker development environment ready!"
    log_info "Container: $DEV_CONTAINER_NAME"
    log_info "Image: $DEV_IMAGE_NAME"
    if [[ -n "$port" ]]; then
        log_info "Port: $port (host) -> 8000 (container)"
        log_info "Access dev server at: http://localhost:$port"
    fi
    log_info "Enter the development shell with:"
    log_info "  docker exec -it $DEV_CONTAINER_NAME nix develop"
}

# Cleanup function
cleanup_docker_dev() {
    local project_root="$1"
    
    log_info "Cleaning up Docker development environment"
    
    # Stop and remove container
    if docker ps | grep -q "$DEV_CONTAINER_NAME"; then
        docker stop "$DEV_CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Clean up any leftover files
    if [[ -d "$project_root/.direnv/bin" ]]; then
        rm -rf "$project_root/.direnv/bin"
        log_debug "Removed old wrapper directory: $project_root/.direnv/bin"
    fi
    
    if [[ -f "$project_root/.dev-port" ]]; then
        rm -f "$project_root/.dev-port"
        log_debug "Removed port file: $project_root/.dev-port"
    fi
    
    log_info "Docker development environment cleaned up"
}

# Handle script arguments
case "${1:-setup}" in
    setup)
        setup_docker_dev "${2:-$PROJECT_ROOT}"
        ;;
    cleanup)
        cleanup_docker_dev "${2:-$PROJECT_ROOT}"
        ;;
    *)
        echo "Usage: $0 {setup|cleanup} [project_root]"
        exit 1
        ;;
esac