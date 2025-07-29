#!/bin/bash

# Test script for development environment setup
# Can be used to test both Nix and Docker workflows

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

# Test basic commands
test_basic_commands() {
    local test_mode="$1"
    
    log_info "Testing basic commands in $test_mode mode"
    
    # Test commands that should be available
    local test_commands="just uv python"
    
    for cmd in $test_commands; do
        log_debug "Testing command: $cmd --version"
        if $cmd --version >/dev/null 2>&1; then
            log_info "✅ $cmd is working"
        else
            log_error "❌ $cmd failed"
            return 1
        fi
    done
}

# Test project-specific commands
test_project_commands() {
    local test_mode="$1"
    
    log_info "Testing project commands in $test_mode mode"
    
    # Test just commands
    log_debug "Testing: just --list"
    if just --list >/dev/null 2>&1; then
        log_info "✅ just --list is working"
    else
        log_error "❌ just --list failed"
        return 1
    fi
    
    # Test dependency installation (dry run)
    log_debug "Testing: uv sync --dry-run"
    if uv sync --dry-run >/dev/null 2>&1; then
        log_info "✅ uv sync (dry-run) is working"
    else
        log_error "❌ uv sync (dry-run) failed"
        return 1
    fi
}

# Test Docker environment specifically
test_docker_environment() {
    log_info "Testing Docker development environment"
    
    cd "$PROJECT_ROOT"
    
    # Force Docker setup by temporarily hiding nix
    local nix_path=""
    if command -v nix >/dev/null 2>&1; then
        nix_path=$(which nix)
        log_debug "Temporarily hiding nix at: $nix_path"
        # Create a temporary PATH without nix
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$(dirname "$nix_path")" | tr '\n' ':' | sed 's/:$//')
    fi
    
    # Run Docker setup
    "$SCRIPT_DIR/docker-dev-setup.sh" setup "$PROJECT_ROOT"
    
    # Test commands
    test_basic_commands "Docker"
    test_project_commands "Docker"
    
    # Cleanup
    "$SCRIPT_DIR/docker-dev-setup.sh" cleanup "$PROJECT_ROOT"
    
    # Restore nix to PATH if it was there
    if [[ -n "$nix_path" ]]; then
        export PATH="$(dirname "$nix_path"):$PATH"
        log_debug "Restored nix to PATH"
    fi
    
    log_info "Docker environment test completed"
}

# Test Nix environment
test_nix_environment() {
    log_info "Testing Nix development environment"
    
    cd "$PROJECT_ROOT"
    
    if ! command -v nix >/dev/null 2>&1; then
        log_warn "Nix not available, skipping Nix test"
        return 0
    fi
    
    if [[ ! -f "$FLAKE_FILE" ]]; then
        log_error "No flake.nix found, cannot test Nix environment"
        return 1
    fi
    
    # Test nix develop
    log_debug "Testing: nix develop --command echo 'Nix shell works'"
    if nix develop --command echo "Nix shell works" >/dev/null 2>&1; then
        log_info "✅ nix develop is working"
    else
        log_error "❌ nix develop failed"
        return 1
    fi
    
    # Test commands in nix shell
    nix develop --command bash -c "$(declare -f test_basic_commands); test_basic_commands 'Nix'"
    nix develop --command bash -c "$(declare -f test_project_commands); test_project_commands 'Nix'"
    
    log_info "Nix environment test completed"
}

# Test the dev-env-setup script
test_dev_env_setup() {
    log_info "Testing dev-env-setup script"
    
    cd "$PROJECT_ROOT"
    
    # Run the setup script
    if "$SCRIPT_DIR/dev-env-setup.sh" "$PROJECT_ROOT"; then
        log_info "✅ dev-env-setup.sh completed successfully"
    else
        log_error "❌ dev-env-setup.sh failed"
        return 1
    fi
    
    log_info "dev-env-setup test completed"
}

# Main test function
run_tests() {
    local test_type="${1:-all}"
    
    case "$test_type" in
        nix)
            test_nix_environment
            ;;
        docker)
            test_docker_environment
            ;;
        setup)
            test_dev_env_setup
            ;;
        all)
            log_info "Running all development environment tests"
            test_nix_environment
            test_docker_environment
            test_dev_env_setup
            log_info "All tests completed successfully! 🎉"
            ;;
        *)
            echo "Usage: $0 {nix|docker|setup|all}"
            echo ""
            echo "  nix    - Test Nix development environment"
            echo "  docker - Test Docker development environment"
            echo "  setup  - Test dev-env-setup script"
            echo "  all    - Run all tests (default)"
            exit 1
            ;;
    esac
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests "${1:-all}"
fi