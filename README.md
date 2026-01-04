# VPS Bootstrap System

**Purpose**: Automated server infrastructure management for prabhanshu.space

This repository manages the bootstrap process for the VPS, ensuring nginx, SSL certificates, and Docker containers are properly configured. It provides NASA-style redundancy - the system can recover from failures automatically.

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

## Relationship with personal-website

This repo depends on `personal-website` for:
- nginx config: `personal-website/deploy/nginx/personal-website.conf`
- Docker containers: `personal-website/docker-compose.yml` and `personal-website/dashboard/docker-compose.yml`

The bootstrap script expects `personal-website` to be deployed at `/root/personal-website` on the VPS.

**Deployment Order**:
1. `personal-website` deploys first (website code, configs, containers)
2. `vps_bootstrap` runs after (ensures nginx + SSL + containers are up)

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
