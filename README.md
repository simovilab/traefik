# Traefik Reverse Proxy Setup

Professional Traefik v3.6 reverse proxy setup for multi-server Docker deployments with automatic SSL certificate management via Let's Encrypt.

## Features

- ✅ Automatic HTTPS with Let's Encrypt
- ✅ HTTP to HTTPS redirect
- ✅ Secure dashboard with authentication
- ✅ Docker integration for automatic service discovery
- ✅ Security headers and rate limiting
- ✅ Structured logging
- ✅ Support for multiple servers
- ✅ Wildcard certificate support (via DNS challenge)
- ✅ Environment-based configuration

## Directory Structure

```
traefik/
├── docker-compose.yml          # Main Docker Compose configuration
├── traefik.yml                 # Traefik static configuration
├── acme.json                   # SSL certificates storage (auto-generated)
├── .env                        # Environment variables (create from .env.example)
├── .env.example                # Environment variables template
├── .gitignore                  # Git ignore rules
├── deploy.sh                   # Deployment automation script
├── config/
│   └── middlewares.yml         # Dynamic middleware configuration
├── examples/
│   └── example-service.yml     # Service configuration examples
├── logs/                       # Traefik logs (auto-generated)
└── README.md                   # This file
```

## Prerequisites

- Docker and Docker Compose v2 installed
- Domain name(s) pointing to your server(s)
- Ports 80 and 443 available (inbound)
- (Optional) DNS provider API credentials for wildcard certificates

## Quick Start

### 1. Initial Setup

```bash
# Create the external Docker network
docker network create traefik_proxy

# Create acme.json with correct permissions
touch acme.json
chmod 600 acme.json

# Create logs directory
mkdir -p logs

# Copy environment template
cp .env.example .env
```

### 2. Configure Environment Variables

Edit `.env` file with your settings:

```bash
# Dashboard domain
TRAEFIK_DASHBOARD_DOMAIN=traefik.yourdomain.com

# Generate dashboard password (requires apache2-utils)
# On macOS: brew install httpd
# On Ubuntu: sudo apt-get install apache2-utils
echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g

# Paste the output in .env as TRAEFIK_DASHBOARD_AUTH value
```

### 3. Set the ACME email

Set `ACME_EMAIL` in `.env` — it is injected into Traefik via the
`TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL` environment
variable, so you do not need to edit `traefik.yml`. It must be a real,
reachable address (Let's Encrypt rejects `example.com`).

### 4. Launch Traefik

**Option A: Using the deployment script**
```bash
./deploy.sh deploy
# Or for interactive menu:
./deploy.sh
```

**Option B: Manual deployment**
```bash
# Start Traefik
docker compose up -d

# Check logs
docker compose logs -f

# Verify status
docker compose ps
```

### 5. Access Dashboard

Visit `https://traefik.yourdomain.com` (or your configured domain) and log in with your credentials.

## Adding Services to Traefik

To route traffic to your containerized applications, add them to the `traefik_proxy` network and configure labels:

### Example: Web Application

```yaml
services:
  webapp:
    image: your-app:latest
    networks:
      - traefik_proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webapp.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.webapp.entrypoints=websecure"
      - "traefik.http.routers.webapp.tls=true"
      - "traefik.http.routers.webapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.webapp.loadbalancer.server.port=8080"

networks:
  traefik_proxy:
    external: true
```

### Example: Multiple Domains

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`app1.com`) || Host(`app2.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls=true"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
```

### Example: Path-Based Routing

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=Host(`yourdomain.com`) && PathPrefix(`/api`)"
  - "traefik.http.routers.api.entrypoints=websecure"
  - "traefik.http.routers.api.tls=true"
  - "traefik.http.routers.api.middlewares=api-stripprefix"
  - "traefik.http.middlewares.api-stripprefix.stripprefix.prefixes=/api"
```

### Example: With Middleware

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.secure-app.rule=Host(`secure.yourdomain.com`)"
  - "traefik.http.routers.secure-app.entrypoints=websecure"
  - "traefik.http.routers.secure-app.tls=true"
  - "traefik.http.routers.secure-app.middlewares=security-headers@file,rate-limit@file"
```

See `examples/example-service.yml` for more configuration examples.

## Multi-Server Deployment

To deploy across multiple servers:

### 1. Clone to Each Server

```bash
# On each server
git clone <repository-url> /opt/traefik
cd /opt/traefik
```

### 2. Configure Per-Server Settings

Each server gets its own `.env` configuration:

```bash
# Server 1 - Main
TRAEFIK_DASHBOARD_DOMAIN=traefik-1.yourdomain.com

# Server 2 - Secondary
TRAEFIK_DASHBOARD_DOMAIN=traefik-2.yourdomain.com

# Server 3 - Tertiary
TRAEFIK_DASHBOARD_DOMAIN=traefik-3.yourdomain.com
```

### 3. Deploy to Each Server

```bash
# On each server
./deploy.sh deploy
```

### 4. DNS Configuration

Point your domains to the appropriate servers:
- Use A records for specific servers
- Use load balancers for high availability
- Consider GeoDNS for regional routing

## SSL Certificates

### HTTP Challenge (Default)

Simple setup, works out of the box:
- Requires ports 80 and 443 open
- One certificate per domain
- Configured by default in `traefik.yml`

### DNS Challenge (Wildcard Support)

For wildcard certificates (`*.yourdomain.com`):

1. Uncomment DNS challenge section in `traefik.yml`:

```yaml
dnsChallenge:
  provider: cloudflare
  delayBeforeCheck: 30
  resolvers:
    - "1.1.1.1:53"
    - "8.8.8.8:53"
```

2. Add DNS provider credentials to `.env`

3. Update domain configuration for wildcard

**Supported DNS Providers:**
- Cloudflare, AWS Route53, Google Cloud DNS
- DigitalOcean, Namecheap, OVH
- [Full list](https://doc.traefik.io/traefik/https/acme/#providers)

### Staging Environment

For testing, use Let's Encrypt staging:

```yaml
# In your service labels
- "traefik.http.routers.myapp.tls.certresolver=letsencrypt-staging"
```

## Security

### Dashboard Authentication

Generate secure passwords:

```bash
# Generate new password
htpasswd -nb admin newpassword | sed -e s/\\$/\\$\\$/g

# Or use the deployment script
./deploy.sh password
```

### IP Allow List

Uncomment and configure in `config/middlewares.yml` (Traefik v3 uses
`ipAllowList`; the v2 `ipWhiteList` name is deprecated):

```yaml
ip-allowlist:
  ipAllowList:
    sourceRange:
      - "YOUR.IP.ADDRESS/32"
      - "10.0.0.0/8"
```

Apply to services:

```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=ip-allowlist@file"
```

### Security Headers

Pre-configured in `config/middlewares.yml`:
- HSTS with preload
- XSS protection
- Content type sniffing prevention
- Frame denial
- Custom security headers

## Monitoring

### View Logs

```bash
# All logs
docker compose logs -f

# Access logs
tail -f logs/access.log

# Error logs
tail -f logs/traefik.log

# Using deployment script
./deploy.sh logs
```

### Metrics (Optional)

Uncomment Prometheus metrics in `traefik.yml` and add:

```yaml
entryPoints:
  metrics:
    address: ":8082"
```

## Troubleshooting

### Certificate Issues

```bash
# Check acme.json
cat acme.json | jq

# Reset certificates
docker compose down
rm acme.json
touch acme.json && chmod 600 acme.json
docker compose up -d
```

### Dashboard Not Accessible

- Verify DNS points to server
- Check firewall allows ports 80 and 443 (the dashboard is served on
  HTTPS via `api@internal`; port 8080 is not used)
- Verify `TRAEFIK_DASHBOARD_DOMAIN` in `.env`
- Check authentication string format (doubled `$$`)

### Service Not Routing

```bash
# Check if service is detected
docker compose exec traefik traefik healthcheck

# Verify network
docker network inspect traefik_proxy

# Check labels
docker inspect <container_name>
```

### Permission Denied on acme.json

```bash
chmod 600 acme.json
chown $USER:$USER acme.json
```

## Maintenance

### Update Traefik

```bash
# Pull latest image
docker compose pull

# Restart with new image
docker compose up -d

# Or use deployment script
./deploy.sh restart

# Check version
docker compose exec traefik traefik version
```

### Backup

```bash
# Backup certificates and config
tar -czf traefik-backup-$(date +%Y%m%d).tar.gz \
  acme.json .env traefik.yml docker-compose.yml config/
```

### Restore

```bash
# Extract backup
tar -xzf traefik-backup-YYYYMMDD.tar.gz

# Set permissions
chmod 600 acme.json

# Restart
docker compose up -d
```

## Deployment Script Usage

The `deploy.sh` script provides an easy way to manage your Traefik deployment:

```bash
# Interactive menu
./deploy.sh

# Direct commands
./deploy.sh deploy      # Full deployment
./deploy.sh setup       # Setup only
./deploy.sh start       # Start Traefik
./deploy.sh stop        # Stop Traefik
./deploy.sh restart     # Restart Traefik
./deploy.sh logs        # View logs
./deploy.sh password    # Generate password
./deploy.sh status      # Check status
./deploy.sh --help      # Show help
```

## Advanced Configuration

### Custom Error Pages

Create `config/errors.yml`:

```yaml
http:
  middlewares:
    error-pages:
      errors:
        status:
          - "400-599"
        service: error-service
        query: /{status}.html

  services:
    error-service:
      loadBalancer:
        servers:
          - url: http://error-pages-container/
```

### TCP/UDP Services

Add to `traefik.yml`:

```yaml
entryPoints:
  postgres:
    address: ":5432"
```

Configure service:

```yaml
labels:
  - "traefik.tcp.routers.postgres.rule=HostSNI(`*`)"
  - "traefik.tcp.routers.postgres.entrypoints=postgres"
  - "traefik.tcp.services.postgres.loadbalancer.server.port=5432"
```

## Version Information

This setup uses **Traefik v3.6**, which includes:
- Improved performance and stability
- Enhanced middleware options
- Better WebAssembly plugin support
- Updated configuration syntax

For migration from v2.x, see the [Traefik v3 Migration Guide](https://doc.traefik.io/traefik/migration/v2-to-v3/).

## Resources

- [Traefik v3 Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Docker Labels Reference](https://doc.traefik.io/traefik/routing/providers/docker/)
- [DNS Providers](https://doc.traefik.io/traefik/https/acme/#providers)

## License

This configuration is provided as-is for use in your projects.

## Support

For issues specific to this setup, check:
1. Logs: `docker compose logs -f`
2. Dashboard: `https://your-dashboard-domain/dashboard/`
3. Traefik docs: https://doc.traefik.io/
