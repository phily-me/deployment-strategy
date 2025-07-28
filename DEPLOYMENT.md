# Python uv Deployment Strategy

This document outlines the complete deployment strategy for Python uv projects to on-premise Docker instances with nginx proxy manager for reverse proxy management.

## Overview

The deployment strategy consists of:
- **Build automation** with `just` commands
- **Containerized deployments** using Docker
- **Nginx proxy manager** for reverse proxy configuration
- **Branch-based subdomains** with automated SSL
- **Automated artifact generation** and deployment

## Architecture

```
[Source Code] → [Build] → [Docker Image] → [Deploy] → [nginx PM] → [Internet]
     ↓              ↓            ↓           ↓          ↓
  justfile    Docker Build   Artifacts   Server    Proxy Manager
                                          ↓
                                Container IP Detection
                              project-branch.example.com
```

## Components

### 1. Build System (`justfile`)

The `justfile` provides automated commands for the entire deployment pipeline:

- `just install` - Install dependencies with uv
- `just test` - Run tests
- `just lint` - Code linting with ruff
- `just build` - Build Docker image
- `just artifacts` - Generate deployment artifacts
- `just deploy <server>` - Deploy to server
- `just deploy-full <server>` - Full pipeline with tests and deployment
- `just setup-npm <container_ip> <port>` - Configure nginx proxy manager

### 2. Docker Configuration

**Dockerfile features:**
- Multi-stage build for optimization
- Security-focused (non-root user)
- Health checks included
- Python 3.11 with uv package manager

**Generated artifacts:**
- Compressed Docker image (`image.tar.gz`)
- Environment-specific docker-compose file

### 3. nginx Proxy Manager Integration

**Features:**
- Automated proxy host creation via API
- SSL termination with Let's Encrypt
- WebSocket support
- Security headers
- Health check endpoints
- Container IP detection

**Subdomain format:** `{project}-{branch}.{domain}`
- Example: `nuuk-feature-auth.example.com`

**Auto-configuration:**
- SSL certificates via Let's Encrypt
- Dynamic port assignment
- Container IP detection

## Usage

### Prerequisites

1. **Server setup:**
   ```bash
   # Install Docker, docker-compose
   # Install and configure nginx proxy manager
   # Ensure nginx proxy manager is running on port 81
   ```

2. **Environment variables:**
   ```bash
   export PROJECT_NAME="nuuk"
   export DOMAIN_SUFFIX="example.com"
   export NPM_API_URL="http://localhost:81/api"
   export NPM_EMAIL="admin@example.com"
   export NPM_PASSWORD="your-npm-password"
   ```

### Quick Deployment

1. **Build and test:**
   ```bash
   just test lint
   ```

2. **Generate artifacts:**
   ```bash
   just artifacts
   ```

3. **Deploy to server:**
   ```bash
   just deploy user@server.com
   ```

4. **Full pipeline:**
   ```bash
   just deploy-full user@server.com
   ```

### Manual Steps

1. **Build Docker image:**
   ```bash
   just build
   ```

2. **Setup nginx proxy manager:**
   ```bash
   just setup-npm 172.17.0.3 8080
   ```

3. **Deploy with custom configuration:**
   ```bash
   scp dist/* user@server:/tmp/
   ssh user@server "bash /tmp/deploy.sh image-tag project branch subdomain"
   ```

## Configuration

### nginx Proxy Manager Setup

**Basic Configuration:**
```bash
export NPM_API_URL="http://localhost:81/api"
export NPM_EMAIL="admin@example.com"
export NPM_PASSWORD="your-password"
export SSL_CERT_ID="1"  # Existing Let's Encrypt cert ID, or 0 for new
```

**SSL Certificate Options:**
- Use existing certificate: Set `SSL_CERT_ID` to existing cert ID
- Request new Let's Encrypt certificate: Set `SSL_CERT_ID=0`
```

**Advanced Configuration:**
```bash
# Custom nginx proxy manager instance
export NPM_API_URL="https://npm.yourcompany.com/api"

# Custom SSL certificate handling
export SSL_CERT_ID="5"  # Use specific certificate ID

# Authentication
export NPM_EMAIL="deploy@yourcompany.com"
export NPM_PASSWORD="secure-password"
```

### Container Management

The deployment script automatically:
- Finds available ports (8080-9000 range)
- Updates docker-compose configuration
- Detects container IP address
- Configures nginx proxy manager via API

## File Structure

```
project/
├── justfile                          # Build automation
├── Dockerfile                        # Container definition
├── templates/
│   └── docker-compose.yml.template  # Container orchestration
├── scripts/
│   ├── deploy.sh                    # Server deployment script
│   └── setup-npm.sh                # nginx proxy manager API script
└── dist/                            # Generated artifacts (gitignored)
    ├── {image}.tar.gz              # Docker image archive
    └── docker-compose-{project}-{branch}.yml
```

## Security Considerations

1. **Container Security:**
   - Non-root user execution
   - Minimal base image
   - Health checks enabled

2. **Network Security:**
   - SSL/TLS termination
   - Security headers
   - Internal container networking

3. **Access Control:**
   - SSH key-based server access
   - API token-based nginx proxy manager access
   - Isolated container environments

## Monitoring and Logging

- **nginx proxy manager logs** via web interface
- **Docker container logs** with rotation
- **Health check endpoints** for monitoring
- **Deployment logging** with timestamps
- **nginx proxy manager API** for monitoring proxy status

## Troubleshooting

### Common Issues

1. **Port conflicts:**
   - Script automatically finds available ports
   - Check `netstat -tuln` for port usage

2. **nginx proxy manager connectivity:**
   - Verify NPM is running on port 81
   - Check API credentials and URL
   - Test with: `curl $NPM_API_URL/ping`

3. **Container startup:**
   - Check logs: `docker logs container-name`
   - Verify health endpoint: `curl localhost:port/health`

4. **Proxy host configuration:**
   - Check nginx proxy manager web interface
   - Verify proxy host is enabled
   - Check SSL certificate status

## Extending the Strategy

### Adding Custom nginx Proxy Manager Features

1. Extend `scripts/setup-npm.sh`
2. Add custom advanced_config sections
3. Implement access lists or custom locations

### Custom Proxy Configurations

1. Modify the API payload in `setup-npm.sh`
2. Add custom headers or upstream settings
3. Configure rate limiting or caching

### Additional Deployment Targets

1. Extend justfile with new deploy commands
2. Create provider-specific deployment scripts
3. Add configuration templates

---

This deployment strategy provides a robust, automated solution for deploying Python uv projects with branch-based environments and nginx proxy manager integration.