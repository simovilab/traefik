# Traefik Setup - File Structure

Complete overview of all files in this Traefik reverse proxy setup.

## Core Configuration Files

### docker-compose.yml
- **Purpose**: Main Docker Compose configuration
- **Contains**: Traefik container definition, networks, ports, volumes, labels
- **Edit**: Rarely (only for version updates or major changes)

### traefik.yml
- **Purpose**: Traefik static configuration
- **Contains**: Entry points, certificate resolvers, providers, logging
- **Edit**: Before first deployment (email, domains)

### acme.json
- **Purpose**: SSL certificate storage
- **Contains**: Let's Encrypt certificates (auto-generated)
- **Permissions**: Must be 600 (chmod 600)
- **Edit**: Never (managed by Traefik)

### .env
- **Purpose**: Environment variables
- **Contains**: Dashboard domain, authentication, DNS credentials
- **Edit**: Before first deployment (required configuration)
- **Security**: Never commit to git

### .env.example
- **Purpose**: Environment variables template
- **Contains**: Example values for all environment variables
- **Edit**: When adding new variables
- **Security**: Safe to commit to git

## Configuration Directories

### config/
Dynamic configuration files loaded by Traefik at runtime.

#### config/middlewares.yml
- **Purpose**: Middleware definitions
- **Contains**: Security headers, rate limiting, CORS, IP whitelisting
- **Edit**: To customize middleware behavior

### examples/
Example configurations for common use cases.

#### examples/example-service.yml
- **Purpose**: Service configuration examples
- **Contains**: Multiple service routing examples
- **Edit**: Copy and customize for your services

## Automation & Documentation

### deploy.sh
- **Purpose**: Deployment automation script
- **Contains**: Interactive menu and CLI commands for deployment
- **Usage**: `./deploy.sh` (interactive) or `./deploy.sh deploy` (direct)
- **Permissions**: Executable (chmod +x)

### README.md
- **Purpose**: Comprehensive documentation
- **Contains**: Full setup guide, configuration, troubleshooting
- **Audience**: All users

### QUICKSTART.md
- **Purpose**: Quick deployment guide
- **Contains**: 5-minute setup instructions
- **Audience**: New users

### DEPLOYMENT_CHECKLIST.md
- **Purpose**: Step-by-step deployment checklist
- **Contains**: Pre-deployment, deployment, and post-deployment tasks
- **Audience**: Operations/DevOps teams

### FILE_STRUCTURE.md
- **Purpose**: This file - overview of all files
- **Contains**: Description of each file and directory
- **Audience**: All users

## Auto-Generated Directories

### logs/
- **Purpose**: Traefik log storage
- **Contains**: traefik.log (application logs), access.log (access logs)
- **Management**: Consider log rotation
- **Edit**: Never (read-only)

## Git Configuration

### .gitignore
- **Purpose**: Git ignore rules
- **Contains**: Files and directories to exclude from version control
- **Important**: Excludes .env, acme.json, logs/

## File Permissions

Critical file permissions:
```
acme.json        → 600 (rw-------)
deploy.sh        → 755 (rwxr-xr-x)
.env             → 600 (rw-------) recommended
traefik.yml      → 644 (rw-r--r--)
docker-compose   → 644 (rw-r--r--)
```

## Customization Guide

### For Initial Deployment
1. Edit `.env` (required)
2. Edit `traefik.yml` email address (required)
3. Optionally edit `config/middlewares.yml`

### For Each New Service
1. Create service docker-compose.yml
2. Add Traefik labels
3. Connect to `traefik_proxy` network

### For Advanced Features
1. Uncomment sections in `traefik.yml` (DNS challenge, metrics)
2. Add custom middleware in `config/`
3. Configure additional entry points

## Backup Priority

**Critical** (must backup):
- acme.json
- .env
- traefik.yml
- config/

**Important** (should backup):
- docker-compose.yml
- deploy.sh

**Optional** (can regenerate):
- logs/
- examples/

## File Modification Workflow

### Before Production
1. Copy `.env.example` to `.env`
2. Edit `.env` with your values
3. Edit `traefik.yml` email
4. Review `config/middlewares.yml`
5. Run `./deploy.sh setup`

### After Production
- Avoid editing core files unless necessary
- Test changes in staging first
- Always backup before making changes
- Use `docker compose down` before major changes

## Quick Reference

```
traefik/
├── docker-compose.yml          → Traefik container config
├── traefik.yml                 → Traefik static config
├── acme.json                   → SSL certificates (auto)
├── .env                        → Environment variables
├── .env.example                → Environment template
├── .gitignore                  → Git exclusions
├── deploy.sh                   → Deployment script ⚙️
├── README.md                   → Full documentation 📖
├── QUICKSTART.md               → 5-min setup guide 🚀
├── DEPLOYMENT_CHECKLIST.md     → Deployment checklist ✅
├── FILE_STRUCTURE.md           → This file 📁
├── config/
│   └── middlewares.yml         → Middleware config
├── examples/
│   └── example-service.yml     → Service examples
└── logs/                       → Application logs (auto)
```

## Need Help?

- Quick setup: See `QUICKSTART.md`
- Full guide: See `README.md`
- Deployment: See `DEPLOYMENT_CHECKLIST.md`
- Service examples: See `examples/example-service.yml`
