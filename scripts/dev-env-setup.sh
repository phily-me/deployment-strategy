#!/bin/bash

# Development environment setup script
# Detects available tools and sets up the appropriate development environment

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main setup function
setup_dev_environment() {
    local project_root="$1"
    
    cd "$project_root"
    
    # Check if nix is available and flake exists
    if command_exists nix && [[ -f "$FLAKE_FILE" ]]; then
        log_info "Nix detected - using native Nix development environment"
        return 0  # Success - use Nix
    fi
    
    # Check if docker is available
    if ! command_exists docker; then
        log_error "Neither Nix nor Docker is available!"
        log_error "Please install one of the following:"
        log_error "  1. Nix: https://nixos.org/download.html"
        log_error "  2. Docker: https://docs.docker.com/get-docker/"
        return 1  # Failure
    fi
    
    log_warn "Nix not available, setting up Docker development container"
    
    # Setup Docker-based development environment
    "$SCRIPT_DIR/docker-dev-setup.sh" "$project_root"
    return $?
}

# Run setup if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_dev_environment "${PROJECT_ROOT:-$(pwd)}"
fi