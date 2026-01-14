#!/bin/bash
set -e

# Setup Deploy Keys for GitHub Actions
# This script manages the authorized_keys for automated deployments
# Usage: ./setup-deploy-keys.sh [add|remove|list]

AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# Unified deploy key for all GitHub Actions deployments
# Fingerprint: SHA256:0/FaydVfteN4xqu70OdgGli3R54JiLvFECM4SIn4/Kg
# Private key stored in pass: github/vps-deploy-key
DEPLOY_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOAO8wEITGBAJ43koYmMX2XZ24J0JhJX+DTxZBUpgvX github-actions-vps-deploy"

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

# Ensure .ssh directory exists
mkdir -p /root/.ssh
chmod 700 /root/.ssh

case "${1:-add}" in
    add)
        log "Adding unified deploy key..."

        # Check if key already exists
        if grep -q "github-actions-vps-deploy" "$AUTHORIZED_KEYS" 2>/dev/null; then
            log "Deploy key already exists in authorized_keys"
        else
            echo "$DEPLOY_KEY" >> "$AUTHORIZED_KEYS"
            chmod 600 "$AUTHORIZED_KEYS"
            log "Deploy key added successfully"
        fi

        # Remove old/duplicate deploy keys
        log "Cleaning up old deploy keys..."
        # Keep only the unified key, remove others with "deploy" in the comment
        sed -i '/github-actions-deploy$/d' "$AUTHORIZED_KEYS"  # Old RSA key
        sed -i '/github-actions-deploy-avanti$/d' "$AUTHORIZED_KEYS"  # Temp key

        log "Deploy key setup complete"
        ;;
    remove)
        log "Removing deploy key..."
        sed -i '/github-actions-vps-deploy/d' "$AUTHORIZED_KEYS"
        log "Deploy key removed"
        ;;
    list)
        log "Current authorized keys:"
        cat "$AUTHORIZED_KEYS"
        ;;
    *)
        echo "Usage: $0 [add|remove|list]"
        exit 1
        ;;
esac
