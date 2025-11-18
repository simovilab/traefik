# Quick Start Guide

Get Traefik up and running in 5 minutes.

## Prerequisites Checklist

- [ ] Docker installed
- [ ] Docker Compose installed
- [ ] Domain pointing to your server
- [ ] Ports 80 and 443 open

## Installation Steps

### 1. Clone or Copy Files
```bash
# If using git
git clone <your-repo> /opt/traefik
cd /opt/traefik

# Or copy files manually to your server
```

### 2. Run Setup Script
```bash
./deploy.sh setup
```

This will:
- Create the `traefik_proxy` Docker network
- Create `acme.json` with correct permissions
- Create logs directory
- Copy `.env.example` to `.env`

### 3. Configure Your Settings

Edit `.env`:
```bash
nano .env
```

**Required changes:**
1. Set `TRAEFIK_DASHBOARD_DOMAIN` to your dashboard domain
2. Generate password hash (see below)
3. Set your email in `traefik.yml`

**Generate password hash:**
```bash
# Option 1: Using the script
./deploy.sh password

# Option 2: Manual
echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g
```

Copy the output and paste it as `TRAEFIK_DASHBOARD_AUTH` in `.env`.

### 4. Update Email in traefik.yml

```bash
nano traefik.yml
```

Find and update:
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com  # <-- Change this
```

### 5. Start Traefik

```bash
./deploy.sh start
```

Or manually:
```bash
docker compose up -d
```

### 6. Verify Installation

Check status:
```bash
docker compose ps
```

View logs:
```bash
docker compose logs -f
```

Access dashboard:
```
https://your-traefik-domain.com
```

## Add Your First Service

Create a `docker-compose.yml` for your app:

```yaml
version: '3.8'

services:
  myapp:
    image: nginx:alpine
    networks:
      - traefik_proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  traefik_proxy:
    external: true
```

Start your app:
```bash
docker compose up -d
```

Traefik will automatically:
- Detect your service
- Route traffic to it
- Generate SSL certificate
- Redirect HTTP to HTTPS

## Troubleshooting

### Can't access dashboard?
- Check DNS: `nslookup your-traefik-domain.com`
- Check firewall: `sudo ufw status`
- Check logs: `docker compose logs traefik`

### Certificate not issued?
- Wait 1-2 minutes for Let's Encrypt
- Check logs: `docker compose logs traefik | grep acme`
- Verify ports 80/443 are accessible from internet

### Service not routing?
```bash
# Check if Traefik sees your service
docker network inspect traefik_proxy

# Check labels on your container
docker inspect <container-name> | grep traefik
```

## Next Steps

- Read full `README.md` for advanced configuration
- Check `examples/example-service.yml` for more routing patterns
- Configure DNS challenge for wildcard certificates
- Set up monitoring and metrics

## Common Commands

```bash
# View all logs
docker compose logs -f

# Stop Traefik
docker compose down

# Restart Traefik
docker compose restart

# Update Traefik
docker compose pull && docker compose up -d

# Check Traefik version
docker compose exec traefik traefik version
```

## Support

Need help? Check:
- Full README: `README.md`
- Traefik docs: https://doc.traefik.io/
- Your logs: `docker compose logs -f`
