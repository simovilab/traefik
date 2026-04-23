# Traefik Deployment Checklist

Use this checklist when deploying Traefik to a new server.

## Pre-Deployment

### Server Requirements
- [ ] Docker installed (version 20.10+)
- [ ] Docker Compose installed (version 2.0+)
- [ ] Server has public IP address
- [ ] Ports 80 and 443 are open in firewall (port 8080 is NOT required)
- [ ] SSH access configured
- [ ] Non-root user with sudo access (recommended)

### DNS Configuration
- [ ] Domain(s) purchased
- [ ] A record(s) pointing to server IP
- [ ] DNS propagation completed (check with `nslookup`)
- [ ] (Optional) DNS API credentials ready for wildcard certs

### Security Preparation
- [ ] Strong password for dashboard created
- [ ] Email address for Let's Encrypt notifications ready
- [ ] SSH keys configured (not password-based access)
- [ ] Firewall rules planned

## Initial Setup

### File Preparation
- [ ] Files copied to server (e.g., `/opt/traefik`)
- [ ] Deploy script is executable (`chmod +x deploy.sh`)
- [ ] `.env.example` exists
- [ ] `traefik.yml` exists
- [ ] `docker-compose.yml` exists
- [ ] `config/middlewares.yml` exists

### Network Setup
- [ ] Docker network created: `docker network create traefik_proxy`
- [ ] Network verified: `docker network ls | grep traefik_proxy`

### File Configuration
- [ ] `acme.json` created with chmod 600
- [ ] `logs/` directory created
- [ ] `.env` file created from `.env.example`

## Configuration

### Environment Variables (.env)
- [ ] `TRAEFIK_DASHBOARD_DOMAIN` set to your real dashboard domain
- [ ] `TRAEFIK_DASHBOARD_AUTH` generated and set
  - Command: `htpasswd -nb admin password | sed -e s/\\$/\\$\\$/g`
  - Or use: `./deploy.sh password`
- [ ] `ACME_EMAIL` set to a real, reachable email (NOT `example.com`)
- [ ] `CERT_RESOLVER` confirmed (default: `letsencrypt`)
- [ ] DNS provider credentials set (only if using DNS challenge)

### Traefik Configuration (traefik.yml)
- [ ] Log level appropriate (INFO for production, DEBUG for troubleshooting)
- [ ] Certificate challenge method chosen (HTTP-01 default, or DNS for wildcards)
- [ ] DNS challenge provider configured (only if applicable)
- [ ] `tls.domains` block re-added with wildcards (only if using DNS challenge)

### Docker Compose (docker-compose.yml)
- [ ] Traefik version pinned (current default: v3.6.2)
- [ ] Ports mapped correctly (80, 443)
- [ ] Healthcheck present
- [ ] Volumes mounted correctly
- [ ] Network set to `traefik_proxy`
- [ ] Environment variables referenced correctly

### Middleware Configuration (config/middlewares.yml)
- [ ] Security headers configured
- [ ] Rate limiting set appropriately
- [ ] IP whitelist configured (if needed)
- [ ] CORS headers configured (if needed)

## Deployment

### Start Traefik
- [ ] Run: `./deploy.sh deploy` or `docker compose up -d`
- [ ] Container started: `docker compose ps`
- [ ] Container healthy: `docker compose logs traefik`
- [ ] No errors in logs

### Verification
- [ ] Dashboard accessible at configured domain
- [ ] Dashboard login works with credentials
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate issued (may take 1-2 minutes)
- [ ] Certificate is valid (check in browser)

### Testing
- [ ] Deploy a test service
- [ ] Test service is routed correctly
- [ ] Test service gets SSL certificate
- [ ] Test service redirects HTTP to HTTPS
- [ ] Middleware applies correctly (check headers)

## Post-Deployment

### Security Hardening
- [ ] Dashboard domain uses strong password
- [ ] Consider IP whitelisting for dashboard
- [ ] Review security headers in middleware
- [ ] Enable rate limiting if not already
- [ ] Review firewall rules
- [ ] SSH password authentication disabled (key-only)

### Monitoring Setup
- [ ] Log rotation configured
- [ ] Disk space monitored (for logs and certificates)
- [ ] Consider enabling Prometheus metrics
- [ ] Set up log aggregation (optional)
- [ ] Configure alerts for certificate renewal failures

### Documentation
- [ ] Server details documented (IP, domain, credentials location)
- [ ] DNS records documented
- [ ] Backup procedure documented
- [ ] Recovery procedure documented
- [ ] Team members have access to documentation

### Backup
- [ ] Initial backup created
  - Command: `tar -czf traefik-backup-$(date +%Y%m%d).tar.gz acme.json .env traefik.yml config/`
- [ ] Backup stored securely off-server
- [ ] Backup schedule planned (weekly recommended)
- [ ] Restore procedure tested

## Adding Services

For each new service:
- [ ] Service added to `traefik_proxy` network
- [ ] Traefik labels configured correctly
- [ ] Domain DNS configured (A record)
- [ ] Service deployed: `docker compose up -d`
- [ ] Service accessible via HTTPS
- [ ] Certificate issued correctly
- [ ] Logs show no errors

## Multi-Server Deployment

If deploying to multiple servers:
- [ ] Each server has unique dashboard domain
- [ ] Each server's `.env` configured independently
- [ ] Load balancer configured (if applicable)
- [ ] GeoDNS configured (if applicable)
- [ ] All servers tested independently
- [ ] Failover tested (if applicable)

## Maintenance Schedule

### Daily
- [ ] Monitor logs for errors
- [ ] Check certificate status

### Weekly
- [ ] Review access logs for anomalies
- [ ] Check disk space usage
- [ ] Review rate limiting logs

### Monthly
- [ ] Update Traefik to latest version
- [ ] Review and rotate logs
- [ ] Test backup restoration
- [ ] Review security settings
- [ ] Update documentation

### Quarterly
- [ ] Security audit
- [ ] Performance review
- [ ] Disaster recovery drill
- [ ] Review and update middleware rules

## Troubleshooting Reference

### Dashboard Not Accessible
```bash
# Check container status
docker compose ps

# Check logs
docker compose logs traefik

# Check DNS
nslookup your-dashboard-domain.com

# Check firewall
sudo ufw status
sudo iptables -L -n
```

### Certificate Issues
```bash
# Check certificate status
docker compose exec traefik cat /acme.json | jq

# View ACME logs
docker compose logs traefik | grep -i acme

# Reset certificates
docker compose down
rm acme.json
touch acme.json && chmod 600 acme.json
docker compose up -d
```

### Service Not Routing
```bash
# Check if Traefik sees the service
docker compose logs traefik

# Verify network
docker network inspect traefik_proxy

# Check service labels
docker inspect <container-name> | grep traefik
```

## Emergency Contacts

- [ ] DNS provider support
- [ ] Hosting provider support
- [ ] Let's Encrypt status page: https://letsencrypt.status.io/
- [ ] Traefik community forum: https://community.traefik.io/
- [ ] Team members contact info

## Sign-off

- Deployed by: ___________________
- Date: ___________________
- Server: ___________________
- Verified by: ___________________
- Date: ___________________

## Notes

Add any server-specific notes or deviations from standard deployment:

```
_____________________________________________________________

_____________________________________________________________

_____________________________________________________________

_____________________________________________________________
```
