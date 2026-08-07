#!/bin/bash

#####################################################################
# Traefik Deployment Script
# Quick deployment script for Traefik reverse proxy
#####################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Original invocation, captured in main() so we can re-exec ourselves.
SCRIPT_ARGS=()
# Cache so we only probe the daemon once per run.
DOCKER_ACCESS_OK=false

# Re-exec this script with the 'docker' group active in the new process.
# Needed because group membership is only picked up by *new* sessions.
rerun_with_docker_group() {
    if ! command -v sg &> /dev/null; then
        print_warning "'sg' not available. Log out and back in, then re-run: $0"
        exit 1
    fi

    local cmd
    cmd=$(printf '%q ' "$(readlink -f "$0")" "${SCRIPT_ARGS[@]}")
    print_info "Re-running with the 'docker' group active..."
    exec sg docker -c "$cmd"
}

# Make sure we can actually talk to the Docker daemon, offering to add the
# current user to the 'docker' group if that is what is missing.
ensure_docker_access() {
    if [ "$DOCKER_ACCESS_OK" = true ]; then
        return 0
    fi

    if docker info &> /dev/null; then
        DOCKER_ACCESS_OK=true
        return 0
    fi

    # Root always has socket access, so a failure here is a daemon problem.
    if [ "$EUID" -eq 0 ]; then
        print_error "Cannot reach the Docker daemon even as root"
        print_info "  Start it with: systemctl start docker"
        exit 1
    fi

    if [ ! -S /var/run/docker.sock ]; then
        print_error "/var/run/docker.sock not found — is the Docker daemon running?"
        print_info "  Start it with: sudo systemctl start docker"
        exit 1
    fi

    print_warning "User '$USER' cannot access /var/run/docker.sock"

    # Already a member? Then this shell simply predates the group change.
    if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        print_info "You are already in the 'docker' group, but this shell has a stale group list"
        rerun_with_docker_group
    fi

    if ! getent group docker &> /dev/null; then
        print_error "No 'docker' group exists on this system"
        print_info "  Reinstall Docker or create it: sudo groupadd docker"
        exit 1
    fi

    if ! command -v sudo &> /dev/null; then
        print_error "sudo not available; cannot add '$USER' to the 'docker' group"
        print_info "  Ask an admin to run: usermod -aG docker $USER"
        exit 1
    fi

    print_warning "Members of the 'docker' group have root-equivalent access to this host"
    if [ "${AUTO_DOCKER_GROUP:-}" = "1" ]; then
        REPLY="y"
    else
        read -p "Add '$USER' to the 'docker' group now? (y/N): " -n 1 -r
        echo
    fi

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Docker access required. Re-run with sudo, or add yourself manually:"
        print_info "  sudo usermod -aG docker $USER && newgrp docker"
        exit 1
    fi

    if ! sudo usermod -aG docker "$USER"; then
        print_error "Failed to add '$USER' to the 'docker' group"
        exit 1
    fi
    print_success "Added '$USER' to the 'docker' group (persists across reboots)"
    print_warning "Terminals opened before now still carry the old group list"
    print_info "  Group membership is only applied to new sessions, so this deploy"
    print_info "  will continue in a subshell but your other shells are unaffected."
    print_info "  To use docker there: run 'newgrp docker', or log out and back in."

    rerun_with_docker_group
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker is installed: $(docker --version)"
    else
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        print_success "Docker Compose is installed: $(docker compose version)"
    elif command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is installed: $(docker-compose --version)"
    else
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if running as root (warn if yes)
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Running as root. Consider using a non-root user."
    fi

    # Check we can actually use the daemon (not just that the CLI exists)
    ensure_docker_access
    print_success "Docker daemon is reachable"
}

# Create network
create_network() {
    print_header "Creating Docker Network"
    
    if docker network inspect traefik_proxy &> /dev/null; then
        print_warning "Network 'traefik_proxy' already exists"
    else
        docker network create traefik_proxy
        print_success "Network 'traefik_proxy' created"
    fi
}

# Setup files
setup_files() {
    print_header "Setting Up Configuration Files"
    
    # Create acme.json
    if [ ! -f acme.json ]; then
        touch acme.json
        chmod 600 acme.json
        print_success "Created acme.json with correct permissions"
    else
        chmod 600 acme.json
        print_warning "acme.json already exists, updated permissions"
    fi
    
    # Create logs directory
    if [ ! -d logs ]; then
        mkdir -p logs
        print_success "Created logs directory"
    else
        print_warning "logs directory already exists"
    fi
    
    # Create config directory
    if [ ! -d config ]; then
        mkdir -p config
        print_success "Created config directory"
    else
        print_warning "config directory already exists"
    fi
    
    # Check .env file
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_warning ".env file created from .env.example"
            print_warning "Please edit .env with your configuration before starting Traefik"
            ENV_CONFIGURED=false
        else
            print_error ".env.example not found"
            exit 1
        fi
    else
        print_success ".env file exists"
        ENV_CONFIGURED=true
    fi
}

# Validate configuration
validate_config() {
    print_header "Validating Configuration"

    if [ ! -f .env ]; then
        print_error ".env file not found. Run: ./deploy.sh setup"
        exit 1
    fi

    # Load .env safely for validation.
    # shellcheck disable=SC1091
    set -a
    . ./.env
    set +a

    local errors=0

    if [ -z "${TRAEFIK_DASHBOARD_DOMAIN:-}" ] || \
       [[ "$TRAEFIK_DASHBOARD_DOMAIN" == *example.com ]]; then
        print_error "TRAEFIK_DASHBOARD_DOMAIN is unset or still uses example.com"
        errors=$((errors+1))
    fi

    if [ -z "${TRAEFIK_DASHBOARD_AUTH:-}" ] || \
       [[ "$TRAEFIK_DASHBOARD_AUTH" == *xxxxxxxx* ]]; then
        print_error "TRAEFIK_DASHBOARD_AUTH is unset or still contains placeholder"
        print_info "  Generate with: ./deploy.sh password"
        errors=$((errors+1))
    fi

    # ACME_EMAIL is now authoritative (injected into Traefik via
    # TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL). Let's Encrypt
    # rejects example.com, so fail hard here.
    if [ -z "${ACME_EMAIL:-}" ] || \
       [[ "$ACME_EMAIL" == *@example.com ]] || \
       [[ "$ACME_EMAIL" == *@yourdomain.com ]]; then
        print_error "ACME_EMAIL is unset or uses a forbidden placeholder domain"
        print_info "  Let's Encrypt rejects example.com / yourdomain.com addresses"
        errors=$((errors+1))
    fi

    if [ "${CERT_RESOLVER:-letsencrypt}" != "letsencrypt" ]; then
        print_warning "CERT_RESOLVER is set to '$CERT_RESOLVER' — make sure it"
        print_warning "matches a resolver defined in traefik.yml"
    fi

    if [ "$errors" -gt 0 ]; then
        print_error "Configuration invalid ($errors error(s)). Aborting."
        exit 1
    fi

    print_success "Configuration looks good"
}

# Start Traefik
start_traefik() {
    print_header "Starting Traefik"
    
    if docker compose ps | grep -q traefik; then
        print_warning "Traefik is already running"
        read -p "Do you want to restart? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker compose down
            docker compose up -d
            print_success "Traefik restarted"
        fi
    else
        docker compose up -d
        print_success "Traefik started"
    fi
}

# Show status
show_status() {
    print_header "Traefik Status"

    docker compose ps

    echo -e "\n"
    if [ -f .env ]; then
        local dashboard
        dashboard=$(grep '^TRAEFIK_DASHBOARD_DOMAIN=' .env | cut -d '=' -f2-)
        if [ -n "$dashboard" ]; then
            print_info "Dashboard URL: https://$dashboard"
        fi
    fi
    print_info "View logs: docker compose logs -f"
    print_info "Stop Traefik: docker compose down"

    echo -e "\n"
    print_success "Deployment complete!"
}

# Generate password
generate_password() {
    print_header "Generate Dashboard Password"
    
    if ! command -v htpasswd &> /dev/null; then
        print_error "htpasswd not found"
        print_info "Install with:"
        print_info "  macOS: brew install httpd"
        print_info "  Ubuntu/Debian: sudo apt-get install apache2-utils"
        print_info "  CentOS/RHEL: sudo yum install httpd-tools"
        exit 1
    fi
    
    read -p "Enter username [admin]: " username
    username=${username:-admin}
    
    read -s -p "Enter password: " password
    echo
    
    if [ -z "$password" ]; then
        print_error "Password cannot be empty"
        exit 1
    fi
    
    # Generate password hash
    hash=$(htpasswd -nb "$username" "$password" | sed -e s/\\$/\\$\\$/g)
    
    echo -e "\n"
    print_success "Generated password hash:"
    echo -e "${GREEN}$hash${NC}"
    echo -e "\n"
    print_info "Add this to your .env file as TRAEFIK_DASHBOARD_AUTH"
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Traefik Deployment Script          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"
    echo "1) Full deployment (setup + start)"
    echo "2) Setup only (no start)"
    echo "3) Start Traefik"
    echo "4) Stop Traefik"
    echo "5) Restart Traefik"
    echo "6) View logs"
    echo "7) Generate password"
    echo "8) Check status"
    echo "9) Exit"
    echo ""
}

# Handle menu choice
handle_choice() {
    case $1 in
        1)
            check_prerequisites
            create_network
            setup_files
            if [ "$ENV_CONFIGURED" = true ]; then
                validate_config
                start_traefik
                show_status
            else
                print_warning "Please configure .env file first, then run option 3 to start"
            fi
            ;;
        2)
            check_prerequisites
            create_network
            setup_files
            print_info "Setup complete. Configure .env and run option 3 to start"
            ;;
        3)
            ensure_docker_access
            validate_config
            start_traefik
            show_status
            ;;
        4)
            ensure_docker_access
            docker compose down
            print_success "Traefik stopped"
            ;;
        5)
            ensure_docker_access
            docker compose restart
            print_success "Traefik restarted"
            ;;
        6)
            ensure_docker_access
            docker compose logs -f
            ;;
        7)
            generate_password
            ;;
        8)
            ensure_docker_access
            docker compose ps
            ;;
        9)
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Main script
main() {
    # Remembered so ensure_docker_access() can re-exec us verbatim
    SCRIPT_ARGS=("$@")

    # If arguments provided, run directly
    if [ $# -gt 0 ]; then
        case "$1" in
            --help|-h)
                echo "Usage: $0 [option]"
                echo ""
                echo "Options:"
                echo "  deploy      Full deployment"
                echo "  setup       Setup only"
                echo "  start       Start Traefik"
                echo "  stop        Stop Traefik"
                echo "  restart     Restart Traefik"
                echo "  logs        View logs"
                echo "  password    Generate password"
                echo "  status      Check status"
                echo ""
                echo "Run without arguments for interactive menu"
                exit 0
                ;;
            deploy)
                handle_choice 1
                ;;
            setup)
                handle_choice 2
                ;;
            start)
                handle_choice 3
                ;;
            stop)
                handle_choice 4
                ;;
            restart)
                handle_choice 5
                ;;
            logs)
                handle_choice 6
                ;;
            password)
                handle_choice 7
                ;;
            status)
                handle_choice 8
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    else
        # Interactive menu
        while true; do
            show_menu
            read -p "Select an option: " choice
            handle_choice $choice
            
            if [ "$choice" != "6" ] && [ "$choice" != "9" ]; then
                echo ""
                read -p "Press Enter to continue..."
            fi
        done
    fi
}

main "$@"
