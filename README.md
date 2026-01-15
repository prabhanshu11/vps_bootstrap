# VPS Bootstrap System

**Purpose**: Automated server infrastructure management for the multi-site VPS

This repository manages the bootstrap process for the VPS (72.60.218.33), ensuring nginx, SSL certificates, and Docker containers are properly configured for **all hosted sites**. It provides NASA-style redundancy - the system can recover from failures automatically.

## Hosted Sites

| Site | Domain | Repository | Status |
|------|--------|------------|--------|
| Personal Website | prabhanshu.space | personal-website | Production |
| Avanti Terraform | avantiterraform.com | avantiterraform | Production |

## Architecture

```
vps_bootstrap/
├── scripts/
│   └── bootstrap.sh          # Main bootstrap script (idempotent)
├── systemd/
│   └── vps-bootstrap.service # Systemd service (runs on boot)
├── deploy/
│   └── deploy.sh             # Deployment script (called by GitHub Actions)
└── .github/workflows/
    └── deploy.yml            # CI/CD pipeline
```

## What It Does

The bootstrap system:
1. **Installs dependencies**: nginx, certbot (if not present)
2. **Configures nginx**: Copies config from personal-website repo
3. **Obtains SSL**: Runs certbot if certificates don't exist
4. **Starts containers**: Ensures Docker containers are running
5. **Auto-recovery**: Runs on boot to recover from failures

## Deployment Philosophy

**CRITICAL**: All changes to VPS infrastructure MUST go through this repo.

- ✅ **DO**: Update scripts in this repo, commit, push → GitHub Actions deploys
- ✅ **DO**: Use SSH for read-only diagnostics (logs, status checks)
- ❌ **DON'T**: Manually run commands on VPS that modify state
- ❌ **DON'T**: Copy files, restart services, or modify configs directly on VPS

### Why?
Manual changes create "state drift" - the VPS state differs from what's in git. This makes deployments unpredictable and debugging impossible.

## Multi-Site Architecture

### Site Deployments
Both sites deploy independently via their own GitHub Actions workflows:

| Site | VPS Path | nginx Config | Ports |
|------|----------|--------------|-------|
| personal-website | `/var/www/personal-website` | `prabhanshu.space.conf` | 5000, 3000, 8000 |
| avantiterraform | `/var/www/avantiterraform` | `avantiterraform.conf` | 3001, 8001 |

### Unified Deploy Key
All repos use the SAME SSH deploy key for VPS access:
- **Fingerprint**: `SHA256:0/FaydVfteN4xqu70OdgGli3R54JiLvFECM4SIn4/Kg`
- **Setup script**: `scripts/setup-deploy-keys.sh`
- **Key storage**: `pass show github/vps-deploy-key` (on local machine)

To add a new repo for VPS deployment:
```bash
# Get the key from pass manager
pass show github/vps-deploy-key | gh secret set SSH_PRIVATE_KEY --repo owner/repo

# Or use the setup script
./scripts/setup-deploy-keys.sh add
```

### Multi-Site SSL Warning (CRITICAL)

**The Avantiterraform Incident (Jan 2026)**:
When avantiterraform.com lost its SSL config, nginx with only one SSL-enabled server block served prabhanshu.space content for ALL HTTPS requests to avantiterraform.com.

**Root Cause**: Deployment scripts were overwriting certbot's SSL additions without re-running certbot.

**Solution**: Always use `certbot --reinstall` after copying nginx configs:
```bash
# In deployment scripts
if [ -f /etc/letsencrypt/live/DOMAIN/fullchain.pem ]; then
    certbot --nginx -d DOMAIN --reinstall --redirect --non-interactive
fi
```

**Diagnostic Commands**:
```bash
# Check which sites have SSL
grep -r "listen 443" /etc/nginx/sites-enabled/

# List all certificates
certbot certificates

# Test specific domain
openssl s_client -servername avantiterraform.com -connect avantiterraform.com:443 | openssl x509 -noout -subject
```

## Relationship with Other Repos

### personal-website
- nginx config: `personal-website/deploy/nginx/`
- Docker containers: Main site + dashboard
- Path on VPS: `/var/www/personal-website`

### avantiterraform
- nginx config: `avantiterraform/deploy/nginx/`
- Docker containers: V1 Next.js + API
- Path on VPS: `/var/www/avantiterraform`

**Deployment Order**:
1. Site repos deploy independently (website code, configs, containers)
2. `vps_bootstrap` can run after to ensure nginx + SSL + containers are up

## Manual Deployment (Emergency Only)

If GitHub Actions is down:

```bash
# On VPS as root:
cd /root/vps_bootstrap
git pull
./deploy/deploy.sh
```

This will:
- Install/update the systemd service
- Run the bootstrap script immediately
- Enable auto-run on boot

## Systemd Service

The service runs on boot to ensure the system recovers from reboots/failures:

```bash
# Check status
systemctl status vps-bootstrap.service

# View logs
journalctl -u vps-bootstrap.service -f

# Manually trigger
systemctl start vps-bootstrap.service
```

## Future Expansion

This repo is designed to grow with additional infrastructure needs:
- AI agents (future phase)
- VPN configuration
- Reverse proxies for streaming (sunshine + moonlight)
- Additional monitoring/health checks
- Backup automation

## Troubleshooting

### Website is down
1. Check service status: `systemctl status vps-bootstrap.service`
2. Check logs: `journalctl -u vps-bootstrap.service -n 50`
3. Check nginx: `nginx -t && systemctl status nginx`
4. Check SSL: `certbot certificates`
5. Check containers: `docker ps`

### SSL not working
The bootstrap script will automatically run certbot if certificates don't exist. If it fails:
- Check DNS: `dig prabhanshu.space`
- Check port 80: `netstat -tlnp | grep :80`
- Check certbot logs: `/var/log/letsencrypt/letsencrypt.log`

### One site showing another site's content
This is the "multi-site SSL" issue. If https://siteA.com shows siteB.com content:
1. Check SSL status: `grep -r "listen 443" /etc/nginx/sites-enabled/`
2. One site likely lost its SSL config
3. Fix: Redeploy the affected site (will run certbot --reinstall)
4. Verify: `curl -I https://siteA.com` should show correct certificate

### Bootstrap script failed
1. Check the logs: `journalctl -u vps-bootstrap.service -n 100`
2. Run manually with debug: `bash -x /root/vps_bootstrap/scripts/bootstrap.sh`
3. Fix the issue in this repo, commit, push → auto-deploys

## Development

To test changes locally before deploying:

```bash
# In this repo
cd ~/Programs/vps_bootstrap

# Make changes to scripts/bootstrap.sh
vim scripts/bootstrap.sh

# Test locally (won't actually run on VPS)
bash -n scripts/bootstrap.sh  # Syntax check

# Commit and push
git add .
git commit -m "Description of changes"
git push

# GitHub Actions will deploy automatically
```

## Owner
- GitHub: prabhanshu11
- Email: mail.prabhanshu@gmail.com
- VPS: 72.60.218.33 (srv1065721.hstgr.cloud)
