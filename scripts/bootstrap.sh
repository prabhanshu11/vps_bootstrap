#!/bin/bash
set -e

# VPS Bootstrap Script
# Ensures nginx, SSL, and Docker containers are properly configured
# This script is idempotent - safe to run multiple times

WEBSITE_REPO_PATH="/root/personal-website"
NGINX_CONF_SOURCE="${WEBSITE_REPO_PATH}/deploy/nginx/personal-website.conf"
NGINX_CONF_DEST="/etc/nginx/sites-available/prabhanshu.space"
NGINX_SYMLINK="/etc/nginx/sites-enabled/prabhanshu.space"
DOMAIN="prabhanshu.space"
WWW_DOMAIN="www.prabhanshu.space"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting VPS bootstrap..."

# 1. Ensure nginx is installed
if ! command -v nginx &> /dev/null; then
    log "Installing nginx..."
    apt-get update
    apt-get install -y nginx
else
    log "nginx is already installed"
fi

# 2. Ensure certbot is installed
if ! command -v certbot &> /dev/null; then
    log "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
else
    log "certbot is already installed"
fi

# 3. Ensure website repo exists
if [[ ! -d "$WEBSITE_REPO_PATH" ]]; then
    error "Website repo not found at $WEBSITE_REPO_PATH"
fi

# 4. Copy nginx config from website repo
if [[ -f "$NGINX_CONF_SOURCE" ]]; then
    log "Copying nginx config from website repo..."
    cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_DEST"

    # Create symlink if it doesn't exist
    if [[ ! -L "$NGINX_SYMLINK" ]]; then
        log "Creating nginx symlink..."
        ln -s "$NGINX_CONF_DEST" "$NGINX_SYMLINK"
    fi
else
    error "nginx config not found at $NGINX_CONF_SOURCE"
fi

# 5. Test nginx config
log "Testing nginx configuration..."
nginx -t || error "nginx configuration test failed"

# 6. Check if SSL certificate exists
if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    log "SSL certificate not found. Running certbot..."

    # Reload nginx first to apply any config changes
    systemctl reload nginx

    # Run certbot
    certbot --nginx -d "$DOMAIN" -d "$WWW_DOMAIN" --non-interactive --agree-tos --email mail.prabhanshu@gmail.com || error "certbot failed"

    log "SSL certificate obtained successfully"
else
    log "SSL certificate already exists"

    # Just reload nginx to apply any config changes
    log "Reloading nginx..."
    systemctl reload nginx
fi

# 7. Ensure Docker containers are running
log "Checking Docker containers..."
cd "$WEBSITE_REPO_PATH"

if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    # Check if main website container is running
    if ! docker ps | grep -q personal-website; then
        log "Starting Docker containers..."
        docker-compose up -d
    else
        log "Docker containers are already running"
    fi

    # Check if dashboard containers are running
    if [[ -f "dashboard/docker-compose.yml" ]]; then
        cd dashboard
        if ! docker ps | grep -q habit-tracker; then
            log "Starting dashboard containers..."
            docker-compose up -d
        else
            log "Dashboard containers are already running"
        fi
        cd ..
    fi
else
    log "WARNING: Docker or docker-compose not found. Skipping container checks."
fi

log "Bootstrap complete! Website should be accessible at https://${DOMAIN}"
