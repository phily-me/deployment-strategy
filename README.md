# Python Development and Deployment Strategy

A complete development environment and deployment strategy template demonstrating:
- **Nix/Docker hybrid development environments**
- **Automated deployment to on-premise Docker instances**
- **nginx proxy manager integration with SSL**
- **Branch-based deployment workflows**

## Project Structure

```
project/
├── src/                    # Application source code
├── tests/                  # Test suite  
├── scripts/                # Development and deployment automation
│   ├── docker-setup.sh     # Docker dev environment setup
│   ├── deploy.sh           # Server deployment automation
│   └── setup-npm.sh        # nginx proxy manager integration
├── templates/              # Configuration templates
│   └── docker-compose.yml.template
├── flake.nix              # Nix development environment
├── .env                   # Configuration variables
├── .envrc                 # direnv setup (Nix/Docker detection)
├── Dockerfile             # Production container
├── Dockerfile.dev         # Development container with Nix
├── Justfile              # Build automation commands
└── pyproject.toml        # Project configuration
```

## Development Environment

### Tools Required

| Tool | Purpose |
|------|---------|
| **Nix** | Development environment (preferred) |
| **Docker** | Development environment (fallback) |
| **direnv** | Environment management |

### Setup Options

#### Option 1: Nix (Recommended)
```bash
# Prerequisites: nix, direnv
direnv allow
# → Automatically sets up Nix development shell
just install && just test && just dev
```

#### Option 2: Docker Fallback
```bash
# Prerequisites: docker, direnv  
direnv allow
# → Shows Docker setup instructions
./scripts/docker-setup.sh setup
docker exec -it example-project-dev nix develop
# → Full Nix environment inside container
just install && just test && just dev
```

### Key Features

- **Transparent Tooling**: Same commands work in both Nix and Docker environments
- **Port Conflict Resolution**: Automatically finds available ports (8000-8099)
- **Git Worktree Support**: Handles git worktrees automatically in containers
- **Configurable**: Central `.env` file for all settings

## Deployment Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Developer   │    │ Build       │    │ Target Server   │    │ nginx Proxy     │
│ Machine     │───▶│ Artifacts   │───▶│ Docker Engine   │───▶│ Manager         │
└─────────────┘    └─────────────┘    └─────────────────┘    └─────────────────┘
       │                   │                   │                       │
   ┌───▼───┐          ┌────▼────┐         ┌────▼────┐             ┌────▼────┐
   │ just  │          │ Docker  │         │ Deploy  │             │ Auto    │
   │ build │          │ Image   │         │ Script  │             │ SSL     │
   │       │          │ .tar.gz │         │ & Config│             │ & DNS   │
   └───────┘          └─────────┘         └─────────┘             └─────────┘
                                                │
                            ┌──────────────────▼──────────────────┐
                            │ project-branch.domain.com           │
                            │ ↓                                   │
                            │ Container IP:Port Detection         │
                            │ ↓                                   │
                            │ Automatic Proxy Configuration       │
                            └─────────────────────────────────────┘
```

### Deployment Flow

1. **Local Build**: `just build` creates Docker image and deployment artifacts
2. **Artifact Transfer**: Image and config uploaded to target server via SCP
3. **Container Deployment**: Remote script loads image and starts container
4. **Service Discovery**: Auto-detects container IP and port
5. **Proxy Setup**: Configures nginx proxy manager via API
6. **SSL Provisioning**: Automatic Let's Encrypt certificates
7. **DNS Routing**: Branch-based subdomains (e.g., `myapp-feature.domain.com`)

## Configuration

### Environment Variables (.env)
```bash
# Project Configuration
PROJECT_NAME=myapp
DOMAIN_SUFFIX=example.com

# Development Environment  
DEV_CONTAINER_NAME=myapp-dev
DEV_IMAGE_NAME=myapp-nix
DEV_PORT_START=8000
DEV_PORT_END=8099

# nginx Proxy Manager
NPM_API_URL=http://localhost:81/api
NPM_EMAIL=admin@example.com
NPM_PASSWORD=secure-password
```

## Available Commands

### Development
```bash
just install        # Install dependencies
just test           # Run tests
just lint           # Code linting
just dev            # Start development server
just dev-reload     # Development with auto-reload
```

### Deployment
```bash
just build                    # Build Docker image
just artifacts               # Generate deployment package
just deploy user@server.com  # Deploy to server
just deploy-full user@server  # Full pipeline (test+lint+deploy)
```

### Environment Management
```bash
# Docker environment
./scripts/docker-setup.sh setup    # Create development container
./scripts/docker-setup.sh cleanup  # Remove container and cleanup

# Testing
./scripts/test-dev-env.sh all      # Test both Nix and Docker setups
```

## Deployment Examples

### Branch-Based Deployment
```bash
# Feature branch deployment
git checkout feature/new-api
just deploy-full server.example.com
# → Available at: https://myapp-feature-new-api.example.com

# Production deployment  
git checkout main
just deploy-full prod.example.com
# → Available at: https://myapp-main.example.com
```

### Manual nginx Configuration
```bash
# If automatic proxy setup fails
just setup-npm 172.17.0.3 8080
```

## Template Usage

This repository serves as a template for projects requiring:

1. **Hybrid Development Environments** (Nix + Docker fallback)
2. **Automated Deployment Pipelines** 
3. **Branch-based Testing/Staging**
4. **nginx Proxy Manager Integration**
5. **SSL Certificate Automation**

### Adapting for Your Project

1. **Update `.env`**: Set `PROJECT_NAME`, `DOMAIN_SUFFIX`, etc.
2. **Replace `src/`**: Add your application code
3. **Update `Dockerfile`**: Modify for your runtime requirements  
4. **Customize `Justfile`**: Add project-specific commands
5. **Configure nginx**: Set `NPM_*` variables for your proxy manager

The deployment strategy and development environment setup will work with any containerized application.