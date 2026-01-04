#!/bin/bash
set -e

# Deployment script for vps_bootstrap
# This script is called by GitHub Actions to deploy the bootstrap system

DEPLOY_DIR="/root/vps_bootstrap"
SYSTEMD_SERVICE_SOURCE="$DEPLOY_DIR/systemd/vps-bootstrap.service"
SYSTEMD_SERVICE_DEST="/etc/systemd/system/vps-bootstrap.service"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Deploying vps_bootstrap system..."

# 1. Ensure scripts are executable
log "Making scripts executable..."
chmod +x "$DEPLOY_DIR/scripts/"*.sh

# 2. Copy systemd service file
log "Installing systemd service..."
cp "$SYSTEMD_SERVICE_SOURCE" "$SYSTEMD_SERVICE_DEST"

# 3. Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload

# 4. Enable service (will run on boot)
log "Enabling vps-bootstrap service..."
systemctl enable vps-bootstrap.service

# 5. Run bootstrap now
log "Running bootstrap script..."
"$DEPLOY_DIR/scripts/bootstrap.sh"

log "Deployment complete!"
log "Service status:"
systemctl status vps-bootstrap.service --no-pager || true
