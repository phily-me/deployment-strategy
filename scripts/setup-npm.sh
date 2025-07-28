#!/bin/bash
set -e

# Nginx Proxy Manager setup script
# Usage: setup-npm.sh <subdomain> <container_ip> <container_port>

SUBDOMAIN="$1"
CONTAINER_IP="$2"
CONTAINER_PORT="$3"

if [ -z "$SUBDOMAIN" ] || [ -z "$CONTAINER_IP" ] || [ -z "$CONTAINER_PORT" ]; then
    echo "Usage: $0 <subdomain> <container_ip> <container_port>"
    echo "Example: $0 myapp-feature.example.com 172.17.0.3 8080"
    exit 1
fi

echo "=== Setting up nginx proxy manager for $SUBDOMAIN -> $CONTAINER_IP:$CONTAINER_PORT ==="

# Configuration
NPM_API_URL="${NPM_API_URL:-http://localhost:81/api}"
NPM_EMAIL="${NPM_EMAIL:-admin@example.com}"
NPM_PASSWORD="${NPM_PASSWORD:-changeme}"
SSL_CERT_ID="${SSL_CERT_ID:-1}"  # Let's Encrypt cert ID, or 0 for none

# Login to get token
echo "Authenticating with nginx proxy manager..."
TOKEN_RESPONSE=$(curl -s -X POST "$NPM_API_URL/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$NPM_EMAIL\",\"secret\":\"$NPM_PASSWORD\"}")

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to authenticate with nginx proxy manager"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "Successfully authenticated"

# Check if proxy host already exists
echo "Checking for existing proxy host..."
EXISTING_HOST=$(curl -s -X GET "$NPM_API_URL/nginx/proxy-hosts" \
    -H "Authorization: Bearer $TOKEN" | \
    jq -r ".[] | select(.domain_names[] == \"$SUBDOMAIN\") | .id // empty")

if [ -n "$EXISTING_HOST" ]; then
    echo "Updating existing proxy host (ID: $EXISTING_HOST)..."
    
    # Update existing proxy host
    RESPONSE=$(curl -s -X PUT "$NPM_API_URL/nginx/proxy-hosts/$EXISTING_HOST" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"domain_names\": [\"$SUBDOMAIN\"],
            \"forward_scheme\": \"http\",
            \"forward_host\": \"$CONTAINER_IP\",
            \"forward_port\": $CONTAINER_PORT,
            \"caching_enabled\": false,
            \"block_exploits\": true,
            \"allow_websocket_upgrade\": true,
            \"access_list_id\": 0,
            \"certificate_id\": $SSL_CERT_ID,
            \"ssl_forced\": true,
            \"hsts_enabled\": true,
            \"hsts_subdomains\": false,
            \"http2_support\": true,
            \"advanced_config\": \"# Health check\\nlocation /health {\\n    proxy_pass http://$CONTAINER_IP:$CONTAINER_PORT/health;\\n    access_log off;\\n}\\n\\n# Security headers\\nadd_header X-Frame-Options DENY;\\nadd_header X-Content-Type-Options nosniff;\\nadd_header X-XSS-Protection \\\"1; mode=block\\\";\"
        }")
    
    if echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
        echo "Successfully updated proxy host"
    else
        echo "Error updating proxy host: $RESPONSE"
        exit 1
    fi
else
    echo "Creating new proxy host..."
    
    # Create new proxy host
    RESPONSE=$(curl -s -X POST "$NPM_API_URL/nginx/proxy-hosts" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"domain_names\": [\"$SUBDOMAIN\"],
            \"forward_scheme\": \"http\",
            \"forward_host\": \"$CONTAINER_IP\",
            \"forward_port\": $CONTAINER_PORT,
            \"caching_enabled\": false,
            \"block_exploits\": true,
            \"allow_websocket_upgrade\": true,
            \"access_list_id\": 0,
            \"certificate_id\": $SSL_CERT_ID,
            \"ssl_forced\": true,
            \"hsts_enabled\": true,
            \"hsts_subdomains\": false,
            \"http2_support\": true,
            \"advanced_config\": \"# Health check\\nlocation /health {\\n    proxy_pass http://$CONTAINER_IP:$CONTAINER_PORT/health;\\n    access_log off;\\n}\\n\\n# Security headers\\nadd_header X-Frame-Options DENY;\\nadd_header X-Content-Type-Options nosniff;\\nadd_header X-XSS-Protection \\\"1; mode=block\\\";\"
        }")
    
    if echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
        NEW_ID=$(echo "$RESPONSE" | jq -r '.id')
        echo "Successfully created proxy host (ID: $NEW_ID)"
    else
        echo "Error creating proxy host: $RESPONSE"
        exit 1
    fi
fi

# If SSL cert ID is 0, try to request Let's Encrypt certificate
if [ "$SSL_CERT_ID" = "0" ]; then
    echo "Requesting Let's Encrypt certificate for $SUBDOMAIN..."
    
    CERT_RESPONSE=$(curl -s -X POST "$NPM_API_URL/nginx/certificates" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"provider\": \"letsencrypt\",
            \"domain_names\": [\"$SUBDOMAIN\"],
            \"meta\": {
                \"letsencrypt_agree\": true,
                \"letsencrypt_email\": \"$NPM_EMAIL\"
            }
        }")
    
    if echo "$CERT_RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
        CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.id')
        echo "Successfully requested certificate (ID: $CERT_ID)"
        
        # Update proxy host with new certificate
        HOST_ID="${EXISTING_HOST:-$NEW_ID}"
        curl -s -X PUT "$NPM_API_URL/nginx/proxy-hosts/$HOST_ID" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{
                \"certificate_id\": $CERT_ID,
                \"ssl_forced\": true
            }" >/dev/null
        
        echo "Updated proxy host with new certificate"
    else
        echo "Warning: Failed to request certificate: $CERT_RESPONSE"
        echo "Proxy host created without SSL - you may need to configure SSL manually"
    fi
fi

echo "=== Nginx proxy manager setup completed for $SUBDOMAIN ==="
echo "Proxy configuration:"
echo "  Domain: $SUBDOMAIN"
echo "  Forward to: $CONTAINER_IP:$CONTAINER_PORT"
echo "  SSL: Enabled"
echo "  WebSocket: Enabled"