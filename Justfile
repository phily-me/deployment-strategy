# Porto project deployment automation

# Default recipe - show available commands
default:
    @just --list

# Variables
project_name := env_var_or_default("PROJECT_NAME", "nuuk")
git_branch := `git branch --show-current`
image_tag := project_name + "-" + git_branch
domain_suffix := env_var_or_default("DOMAIN_SUFFIX", "example.com")
subdomain := project_name + "-" + git_branch + "." + domain_suffix

# Install project dependencies
install:
    uv sync

# Run tests
test:
    uv run pytest

# Lint code
lint:
    uv run ruff check .
    uv run ruff format --check .

# Format code
format:
    uv run ruff format .

# Build Docker image
build:
    @echo "Building Docker image: {{image_tag}}"
    docker build -t {{image_tag}} .

# Create deployment artifacts
artifacts: build
    @echo "Creating deployment artifacts..."
    @mkdir -p dist/
    docker save {{image_tag}} | gzip > dist/{{image_tag}}.tar.gz
    @echo "Generating deployment config..."
    @just _generate-config

# Generate deployment configuration
_generate-config:
    @echo "Generating docker-compose config"
    #!/bin/bash
    export project_name="{{project_name}}"
    export git_branch="{{git_branch}}"
    export image_tag="{{image_tag}}"
    export subdomain="{{subdomain}}"
    export container_port="8080"
    envsubst '${project_name}${git_branch}${image_tag}${subdomain}${container_port}' < templates/docker-compose.yml.template > dist/docker-compose-{{project_name}}-{{git_branch}}.yml

# Deploy to server
deploy server_host: artifacts
    @echo "Deploying {{image_tag}} to {{server_host}}"
    scp dist/{{image_tag}}.tar.gz {{server_host}}:/tmp/
    scp dist/docker-compose-{{project_name}}-{{git_branch}}.yml {{server_host}}:/tmp/
    scp scripts/deploy.sh {{server_host}}:/tmp/
    scp scripts/setup-npm.sh {{server_host}}:/tmp/
    ssh {{server_host}} "bash /tmp/deploy.sh {{image_tag}} {{project_name}} {{git_branch}} {{subdomain}}"

# Setup nginx proxy manager entry (requires NPM API credentials)
setup-npm container_ip container_port:
    @echo "Setting up nginx proxy manager for {{subdomain}}"
    ./scripts/setup-npm.sh "{{subdomain}}" "{{container_ip}}" "{{container_port}}"

# Full deployment pipeline
deploy-full server_host: test lint artifacts
    @just deploy {{server_host}}
    @echo "Deployment complete! App available at https://{{subdomain}}"

# Clean up build artifacts
clean:
    rm -rf dist/
    docker rmi {{image_tag}} 2>/dev/null || true

# Development server
dev:
    uv run python main.py

# Development server with FastAPI dev mode (auto-reload)
dev-reload:
    uv run python -m fastapi dev src/hello_svc/asgi.py --port 8000

# Run coverage tests
cov:
    uv run coverage erase
    uv run coverage run -m pytest tests
    uv run coverage combine
    uv run coverage report
    uv run coverage html

# Make HTTP request to running server
req path="" *args:
    curl http://127.0.0.1:8000/{{path}} {{args}}

# Check all (tests, lint, coverage)
check-all: test lint cov