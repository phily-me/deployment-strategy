# Porto Deployment Strategy

A complete Python deployment strategy demonstrating FastAPI application deployment to on-premise Docker instances with nginx proxy manager integration.

## Project Structure

```
hello-svc/
├── src/hello_svc/          # Application source code
│   ├── __init__.py
│   ├── asgi.py            # ASGI application instance
│   └── views.py           # FastAPI routes
├── tests/                 # Test suite
│   ├── __init__.py
│   └── test_views.py     # API tests
├── scripts/              # Deployment scripts
│   ├── deploy.sh         # Server deployment automation
│   └── setup-npm.sh      # Nginx proxy manager API
├── templates/            # Configuration templates
│   └── docker-compose.yml.template
├── main.py              # Application entry point
├── pyproject.toml       # Project configuration & dependencies
├── justfile            # Build automation commands
├── Dockerfile          # Container definition
└── DEPLOYMENT.md       # Deployment documentation
```

## Features

### Application Features
- **FastAPI** web framework with async support
- **Health check endpoint** (`/health`) for monitoring
- **Info endpoint** (`/info`) for service metadata
- **Comprehensive tests** with pytest and TestClient

### Deployment Features
- **nginx proxy manager** integration via API
- **Automatic SSL certificates** with Let's Encrypt
- **Container IP detection** and proxy configuration
- **Branch-based subdomains** (e.g., `project-branch.example.com`)
- **Port auto-assignment** to avoid conflicts
- **Health checks** built into Docker containers

## Quick Start

### 1. Development Setup

The development environment automatically detects if Nix is available and falls back to Docker transparently via `direnv`. The setup is modular and configurable through scripts and environment variables.

#### Prerequisites
- **direnv** - https://direnv.net/docs/installation.html
- **Either Nix** (recommended) - https://nixos.org/download.html
- **Or Docker** (fallback) - https://docs.docker.com/get-docker/

#### Configuration
The project uses a central `.env` file for configuration:
```bash
# Edit .env to customize settings
PROJECT_NAME=nuuk
DOMAIN_SUFFIX=example.com
DEV_CONTAINER_NAME=porto-dev-container
DEV_IMAGE_NAME=porto-dev-nix
# ... more settings
```

#### Setup
```bash
# Allow direnv in the project directory (one time)
direnv allow

# direnv will automatically:
# - Use Nix if available (preferred) 
# - Build and run Docker container with Nix if Docker available
# - Fail with helpful message if neither available

# With Nix: commands work directly
# With Docker: enter the container shell first
docker exec -it porto-dev-container nix develop

# Then use normal commands in either environment:
just install       # Install dependencies
just test          # Run tests  
just dev           # Start development server
just dev-reload    # Start with auto-reload
just check-all     # Run all checks
```

#### Manual Testing
You can test the development environment setup manually:
```bash
# Test all environments
./scripts/test-dev-env.sh all

# Test specific environments
./scripts/test-dev-env.sh nix     # Test Nix only
./scripts/test-dev-env.sh docker  # Test Docker only
./scripts/test-dev-env.sh setup   # Test setup script
```

#### Direct Script Usage
For template projects or CI/CD, use the scripts directly:
```bash
# Setup development environment
./scripts/dev-env-setup.sh

# Setup Docker environment specifically  
./scripts/docker-dev-setup.sh setup

# Cleanup Docker environment
./scripts/docker-dev-setup.sh cleanup
```

The experience is identical in both environments - just run commands directly with Nix, or enter the container shell first with Docker!

### 2. Local Testing

```bash
# Test the API endpoints
curl http://localhost:8000/                # Hello World
curl http://localhost:8000/health          # Health check  
curl http://localhost:8000/info            # Service info

# Or use the built-in request helper
just req                    # GET /
just req health            # GET /health
just req info              # GET /info
```

### 3. Production Deployment

```bash
# Set environment variables
export PROJECT_NAME="hello-svc"
export DOMAIN_SUFFIX="example.com"
export NPM_API_URL="http://localhost:81/api"
export NPM_EMAIL="admin@example.com"
export NPM_PASSWORD="your-password"

# Full deployment pipeline
just deploy-full user@server.com
```

## API Endpoints

| Endpoint | Method | Description | Response |
|----------|--------|-------------|----------|
| `/` | GET | Hello World message | `{"message": "Hello World"}` |
| `/health` | GET | Health check for monitoring | `{"status": "healthy"}` |
| `/info` | GET | Service information | Service metadata object |

## Deployment Architecture

```
[Developer] → [Build] → [Docker] → [Deploy] → [nginx PM] → [Internet]
     ↓           ↓         ↓          ↓          ↓
   justfile   Container  Artifacts  Server   Proxy Config
                           ↓          ↓
                     Auto-upload  IP Detection
                                     ↓
                              project-branch.example.com
```

## Environment Variables

### Development
```bash
PROJECT_NAME="hello-svc"        # Project identifier
DOMAIN_SUFFIX="example.com"     # Base domain
```

### nginx Proxy Manager
```bash
NPM_API_URL="http://localhost:81/api"    # API endpoint
NPM_EMAIL="admin@example.com"            # Login email
NPM_PASSWORD="secure-password"           # Login password
SSL_CERT_ID="1"                         # Certificate ID (0=new)
```

## Available Commands

### Development Commands
- `just install` - Install dependencies with uv
- `just dev` - Start production-like server
- `just dev-reload` - Start with auto-reload for development
- `just test` - Run pytest test suite
- `just lint` - Run ruff linting and formatting checks
- `just format` - Auto-format code with ruff
- `just cov` - Run tests with coverage reporting
- `just check-all` - Run all quality checks

### Deployment Commands
- `just build` - Build Docker image
- `just artifacts` - Generate deployment artifacts
- `just deploy <server>` - Deploy to server
- `just deploy-full <server>` - Complete deployment pipeline
- `just setup-npm <ip> <port>` - Configure nginx proxy manager
- `just clean` - Clean up build artifacts

### Utility Commands
- `just req [path]` - Make HTTP request to running server

## Docker Container

The application runs in a secure Docker container:

- **Multi-stage build** for smaller production images
- **Non-root user** for security
- **Health checks** using the `/health` endpoint
- **Port 8000** exposed for the application
- **Python 3.11+** with uv package manager

## nginx Proxy Manager Integration

The deployment automatically configures nginx proxy manager:

1. **Detects container IP** after deployment
2. **Creates proxy host** via API
3. **Configures SSL certificates** (Let's Encrypt)
4. **Sets security headers** and WebSocket support
5. **Enables health check** routing

## Testing

The project includes comprehensive tests:

```bash
# Run specific test file
uv run pytest tests/test_views.py

# Run with verbose output
just test -v

# Generate coverage report
just cov
```

## Contributing

1. Make changes to the code
2. Run quality checks: `just check-all`
3. Ensure tests pass: `just test`
4. Test deployment locally if possible

## Deployment Examples

### Simple Deployment
```bash
# Deploy to staging
just deploy-full staging.example.com
# → Available at: https://hello-svc-main.example.com
```

### Feature Branch Deployment
```bash
# Switch to feature branch
git checkout feature/new-api

# Deploy feature branch
just deploy-full staging.example.com  
# → Available at: https://hello-svc-feature-new-api.example.com
```

### Manual nginx Proxy Manager Setup
```bash
# If you need to configure proxy manually
just setup-npm 172.17.0.3 8080
```

This deployment strategy provides a complete, production-ready solution for deploying Python FastAPI applications with automated reverse proxy configuration and SSL certificate management.
