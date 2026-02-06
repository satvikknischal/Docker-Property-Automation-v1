#!/bin/bash

# Docker Property Automation - Setup Script
# This script helps set up the environment for a new server deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}"
echo "============================================"
echo "Barium - Property Automation - Setup"
echo "============================================"
echo -e "${NC}"

# ============================================
# Function: Check if running as root
# ============================================
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
        echo -e "${YELLOW}Note: Some commands may require sudo password${NC}"
    fi
}

# ============================================
# Function: Check and install Docker
# ============================================
check_docker() {
    echo -e "${BLUE}Checking Docker installation...${NC}"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | tr -d ',')
        echo -e "${GREEN}✓ Docker is installed (version $DOCKER_VERSION)${NC}"
        return 0
    else
        echo -e "${YELLOW}Docker is not installed.${NC}"
        read -p "Do you want to install Docker? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${RED}Docker is required. Exiting.${NC}"
            exit 1
        fi
        install_docker
    fi
}

install_docker() {
    echo -e "${BLUE}Installing Docker...${NC}"
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}Cannot detect OS. Please install Docker manually.${NC}"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            echo "Installing Docker on $OS..."
            $SUDO apt-get update
            $SUDO apt-get install -y ca-certificates curl gnupg
            $SUDO install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
            $SUDO apt-get update
            $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|fedora)
            echo "Installing Docker on $OS..."
            $SUDO dnf -y install dnf-plugins-core
            $SUDO dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            $SUDO systemctl start docker
            $SUDO systemctl enable docker
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            echo "Please install Docker manually: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac
    
    # Add current user to docker group
    if [ "$EUID" -ne 0 ]; then
        $SUDO usermod -aG docker $USER
        echo -e "${YELLOW}⚠️  You've been added to the docker group.${NC}"
        echo -e "${YELLOW}   Please log out and back in, then run this script again.${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}✓ Docker installed successfully${NC}"
}

# ============================================
# Function: Check Docker Compose
# ============================================
check_docker_compose() {
    echo -e "${BLUE}Checking Docker Compose...${NC}"
    
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        echo -e "${GREEN}✓ Docker Compose is installed (version $COMPOSE_VERSION)${NC}"
        return 0
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f4 | tr -d ',')
        echo -e "${GREEN}✓ Docker Compose (standalone) is installed (version $COMPOSE_VERSION)${NC}"
        echo -e "${YELLOW}Note: Consider upgrading to Docker Compose V2 (docker compose plugin)${NC}"
        return 0
    else
        echo -e "${RED}Docker Compose is not installed.${NC}"
        echo "Docker Compose should be included with Docker. Please reinstall Docker."
        exit 1
    fi
}

# ============================================
# Function: Check Docker is running
# ============================================
check_docker_running() {
    echo -e "${BLUE}Checking Docker daemon...${NC}"
    
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${YELLOW}Docker daemon is not running. Starting...${NC}"
        $SUDO systemctl start docker
        sleep 2
        if docker info &> /dev/null; then
            echo -e "${GREEN}✓ Docker daemon started${NC}"
        else
            echo -e "${RED}Failed to start Docker daemon${NC}"
            exit 1
        fi
    fi
}

# ============================================
# Function: Generate random password/secret
# ============================================
generate_password() {
    local length=${1:-32}
    local type=${2:-"hex"}
    
    case $type in
        "hex")
            openssl rand -hex $length 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c $((length * 2))
            ;;
        "base64")
            openssl rand -base64 $length 2>/dev/null | tr -d '/+=' | head -c $length
            ;;
        "alnum")
            cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $length
            ;;
    esac
}

# ============================================
# Function: Generate all secrets
# ============================================
generate_all_secrets() {
    echo ""
    echo -e "${BLUE}Generating secure passwords and secrets...${NC}"
    
    # VaultWarden Admin Token
    local VW_TOKEN=$(generate_password 48 base64)
    sed -i.bak "s|^# VAULTWARDEN_ADMIN_TOKEN=.*|VAULTWARDEN_ADMIN_TOKEN=$VW_TOKEN|" .env
    sed -i.bak "s|^VAULTWARDEN_ADMIN_TOKEN=.*|VAULTWARDEN_ADMIN_TOKEN=$VW_TOKEN|" .env
    echo -e "  ${GREEN}✓${NC} VaultWarden Admin Token"
    
    # n8n Encryption Key
    local N8N_KEY=$(generate_password 32 hex)
    sed -i.bak "s|^# N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$N8N_KEY|" .env
    sed -i.bak "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$N8N_KEY|" .env
    echo -e "  ${GREEN}✓${NC} n8n Encryption Key"
    
    # n8n Basic Auth Password
    local N8N_AUTH_PASS=$(generate_password 16 alnum)
    sed -i.bak "s|^N8N_BASIC_AUTH_PASSWORD=.*|N8N_BASIC_AUTH_PASSWORD=$N8N_AUTH_PASS|" .env
    echo -e "  ${GREEN}✓${NC} n8n Basic Auth Password"
    
    # Minecraft RCON Password
    local MC_RCON=$(generate_password 16 alnum)
    sed -i.bak "s|^MC_RCON_PASSWORD=.*|MC_RCON_PASSWORD=$MC_RCON|" .env
    echo -e "  ${GREEN}✓${NC} Minecraft RCON Password"
    
    # LiteLLM Keys
    local LITELLM_MASTER=$(generate_password 32 hex)
    local LITELLM_SALT=$(generate_password 32 hex)
    local LITELLM_UI_PASS=$(generate_password 24 alnum)
    local LITELLM_DB_PASS=$(generate_password 24 alnum)
    sed -i.bak "s|^LITELLM_MASTER_KEY=.*|LITELLM_MASTER_KEY=$LITELLM_MASTER|" .env
    sed -i.bak "s|^LITELLM_SALT_KEY=.*|LITELLM_SALT_KEY=$LITELLM_SALT|" .env
    sed -i.bak "s|^LITELLM_UI_PASSWORD=.*|LITELLM_UI_PASSWORD=$LITELLM_UI_PASS|" .env
    sed -i.bak "s|^LITELLM_DB_PASSWORD=.*|LITELLM_DB_PASSWORD=$LITELLM_DB_PASS|" .env
    echo -e "  ${GREEN}✓${NC} LiteLLM Master Key, Salt Key, UI Password, DB Password"
    
    # Immich Database Password
    local IMMICH_DB_PASS=$(generate_password 32 alnum)
    sed -i.bak "s|^IMMICH_DB_PASSWORD=.*|IMMICH_DB_PASSWORD=$IMMICH_DB_PASS|" .env
    echo -e "  ${GREEN}✓${NC} Immich Database Password"
    
    # BookLore Database Passwords
    local BOOKLORE_DB_PASS=$(generate_password 24 alnum)
    local BOOKLORE_ROOT_PASS=$(generate_password 24 alnum)
    sed -i.bak "s|^BOOKLORE_DB_PASSWORD=.*|BOOKLORE_DB_PASSWORD=$BOOKLORE_DB_PASS|" .env
    sed -i.bak "s|^BOOKLORE_DB_ROOT_PASSWORD=.*|BOOKLORE_DB_ROOT_PASSWORD=$BOOKLORE_ROOT_PASS|" .env
    echo -e "  ${GREEN}✓${NC} BookLore Database Passwords"
    
    # Tandoor Secrets
    local TANDOOR_SECRET=$(generate_password 32 hex)
    local TANDOOR_DB_PASS=$(generate_password 24 alnum)
    sed -i.bak "s|^TANDOOR_SECRET_KEY=.*|TANDOOR_SECRET_KEY=$TANDOOR_SECRET|" .env
    sed -i.bak "s|^TANDOOR_DB_PASSWORD=.*|TANDOOR_DB_PASSWORD=$TANDOOR_DB_PASS|" .env
    echo -e "  ${GREEN}✓${NC} Tandoor Secret Key & Database Password"
    
    # Obsidian LiveSync Password
    local OBSIDIAN_PASS=$(generate_password 24 alnum)
    sed -i.bak "s|^OBSIDIAN_SYNC_PASSWORD=.*|OBSIDIAN_SYNC_PASSWORD=$OBSIDIAN_PASS|" .env
    echo -e "  ${GREEN}✓${NC} Obsidian LiveSync Password"
    
    # Cleanup backup files
    rm -f .env.bak
    
    echo ""
    echo -e "${GREEN}✓ Generated secure passwords for all services${NC}"
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  IMPORTANT: All passwords are stored in .env               ║${NC}"
    echo -e "${YELLOW}║     Back up this file securely!                                 ║${NC}"
    echo -e "${YELLOW}║     You can view generated passwords with: cat .env            ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================
# Function: Create .env file
# ============================================
create_env_file() {
echo ""
    echo -e "${BLUE}Setting up environment configuration...${NC}"
    
    local REGENERATE_SECRETS=false

# Check if .env already exists
if [ -f ".env" ]; then
        echo -e "${YELLOW}⚠️  .env file already exists!${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing .env file."
            read -p "Do you want to regenerate secrets/passwords? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                generate_all_secrets
            fi
            return 0
        fi
        REGENERATE_SECRETS=true
fi

# Create .env from example if it doesn't exist
if [ ! -f ".env.example" ]; then
        echo -e "${YELLOW}Creating .env.example template...${NC}"
        create_env_template
    fi

    # Copy .env.example to .env
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file from .env.example${NC}"

    # Get user IDs
    echo ""
    echo "Detecting user IDs..."
    PUID=$(id -u)
    PGID=$(id -g)
    echo "Found PUID=$PUID, PGID=$PGID"

    # Update .env with detected values
    sed -i.bak "s/^PUID=.*/PUID=$PUID/" .env
    sed -i.bak "s/^PGID=.*/PGID=$PGID/" .env
    rm -f .env.bak

    # Get timezone
    echo ""
    read -p "Enter your timezone (e.g., America/New_York, UTC) [UTC]: " TZ_INPUT
    TZ_INPUT=${TZ_INPUT:-UTC}
    sed -i.bak "s/^TZ=.*/TZ=$TZ_INPUT/" .env
    rm -f .env.bak

    # Get domain
    echo ""
    read -p "Enter your base domain (e.g., example.com): " BASE_DOMAIN
    if [ ! -z "$BASE_DOMAIN" ]; then
        sed -i.bak "s/^BASE_DOMAIN=.*/BASE_DOMAIN=$BASE_DOMAIN/" .env
        sed -i.bak "s|^VAULTWARDEN_DOMAIN=.*|VAULTWARDEN_DOMAIN=https://keys.$BASE_DOMAIN|" .env
        rm -f .env.bak
    fi
    
    # Generate all secrets
    generate_all_secrets
    
    echo -e "${GREEN}✓ Environment configured${NC}"
}

# ============================================
# Function: Create Docker network
# ============================================
create_docker_network() {
    echo ""
    echo -e "${BLUE}Setting up Docker network...${NC}"
    
    if docker network inspect proxy-network >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Network 'proxy-network' already exists${NC}"
    else
        docker network create proxy-network
        echo -e "${GREEN}✓ Created network 'proxy-network'${NC}"
    fi
}

# ============================================
# Function: Display application menu
# ============================================
display_app_menu() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Select Applications to Install${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo -e "${YELLOW}Infrastructure:${NC}"
    echo "  1) Nginx Proxy Manager    - Reverse proxy with SSL"
    echo "  2) Portainer              - Docker management UI"
    echo "  3) Cloudflared            - Cloudflare Tunnel"
    echo "  4) Uptime Kuma            - Status monitoring"
    echo ""
    echo -e "${YELLOW}Media & Entertainment:${NC}"
    echo "  5) Plex                   - Media streaming server"
    echo "  6) Frigate                - AI-powered NVR"
    echo "  7) Arr-Stack              - Prowlarr, Radarr, Sonarr, Overseerr"
    echo "  8) qBittorrent            - Torrent client"
    echo "  9) SABnzbd                - Usenet client"
    echo ""
    echo -e "${YELLOW}AI & LLM:${NC}"
    echo " 10) Open WebUI             - LLM chat interface"
    echo " 11) LiteLLM                - LLM API proxy"
    echo " 12) Perplexica             - AI search engine"
    echo " 13) SearXNG                - Privacy search"
    echo " 14) Whisper STT            - Speech-to-text"
    echo " 15) Piper TTS              - Text-to-speech"
    echo ""
    echo -e "${YELLOW}Productivity:${NC}"
    echo " 16) VaultWarden            - Password manager"
    echo " 17) NextCloud AIO          - Cloud storage"
    echo " 18) n8n                    - Workflow automation"
    echo " 19) StirlingPDF            - PDF tools"
    echo " 20) Homarr                 - Dashboard"
    echo ""
    echo -e "${YELLOW}Home & Utility:${NC}"
    echo " 21) Homebridge             - HomeKit bridge"
    echo " 22) Immich                 - Photo management"
    echo " 23) Tandoor                - Recipe manager"
    echo ""
    echo -e "${YELLOW}Books:${NC}"
    echo " 24) BookLore               - Book library"
    echo " 25) Shelfmark              - Book downloader"
    echo ""
    echo -e "${YELLOW}Other:${NC}"
    echo " 26) Obsidian LiveSync      - Note sync server"
    echo " 27) Minecraft Server       - Game server"
    echo " 28) NTP Server             - Time server"
    echo ""
    echo -e "${GREEN}  A) Install ALL applications${NC}"
    echo -e "${BLUE}  S) Skip - Configure .env only${NC}"
    echo -e "${RED}  Q) Quit${NC}"
    echo ""
}

# ============================================
# Function: Install selected application
# ============================================
install_app() {
    local app_dir=$1
    local app_name=$2
    
    if [ -d "$app_dir" ]; then
        echo -e "${BLUE}Installing $app_name...${NC}"
        cd "$app_dir"
        # Use --env-file to pass root .env for variable substitution in compose files
        if docker compose --env-file "$SCRIPT_DIR/.env" up -d; then
            echo -e "${GREEN}✓ $app_name installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install $app_name${NC}"
        fi
        cd "$SCRIPT_DIR"
    else
        echo -e "${RED}✗ Directory not found: $app_dir${NC}"
    fi
}

# ============================================
# Function: Process user selection
# ============================================
process_selection() {
    local selection=$1
    
    case $selection in
        1) install_app "Nginx-Proxy-Manager" "Nginx Proxy Manager" ;;
        2) install_app "Portainer" "Portainer" ;;
        3) install_app "Cloudflared" "Cloudflared" ;;
        4) install_app "Uptime-Kuma" "Uptime Kuma" ;;
        5) install_app "Plex" "Plex" ;;
        6) install_app "Frigate" "Frigate" ;;
        7) 
            install_app "Arr-Stack/Prowlarr" "Prowlarr"
            install_app "Arr-Stack/Radarr" "Radarr"
            install_app "Arr-Stack/Sonarr" "Sonarr"
            install_app "Arr-Stack/Overseerr" "Overseerr"
            ;;
        8) install_app "qBittorrent" "qBittorrent" ;;
        9) install_app "SabNZBd" "SABnzbd" ;;
        10) install_app "OpenWebUI" "Open WebUI" ;;
        11) install_app "LiteLLM" "LiteLLM" ;;
        12) install_app "Perplexica" "Perplexica" ;;
        13) install_app "SearXNG" "SearXNG" ;;
        14) install_app "Whisper-STT" "Whisper STT" ;;
        15) install_app "Piper-TTS" "Piper TTS" ;;
        16) install_app "VaultWarden" "VaultWarden" ;;
        17) install_app "NextCloud-AIO" "NextCloud AIO" ;;
        18) install_app "n8n" "n8n" ;;
        19) install_app "StirlingPDF" "StirlingPDF" ;;
        20) install_app "Homarr" "Homarr" ;;
        21) install_app "Homebridge" "Homebridge" ;;
        22) install_app "Immich" "Immich" ;;
        23) install_app "Tandoor" "Tandoor" ;;
        24) install_app "Book-Worms/BookLore" "BookLore" ;;
        25) install_app "Book-Worms/Shelfmark" "Shelfmark" ;;
        26) install_app "Obsidian-LiveSync" "Obsidian LiveSync" ;;
        27) install_app "Minecraft-Server" "Minecraft Server" ;;
        28) install_app "NTP-Server" "NTP Server" ;;
        *)
            echo -e "${RED}Invalid selection: $selection${NC}"
            ;;
    esac
}

# ============================================
# Function: Install all applications
# ============================================
install_all_apps() {
    echo ""
    echo -e "${CYAN}Installing all applications...${NC}"
    echo -e "${YELLOW}This may take a while...${NC}"
    echo ""
    
    # Infrastructure first
    install_app "Nginx-Proxy-Manager" "Nginx Proxy Manager"
    install_app "Portainer" "Portainer"
    
    # Then other services
    for i in {3..28}; do
        process_selection $i
    done
    
    echo ""
    echo -e "${GREEN}✓ All applications installed${NC}"
}

# ============================================
# Function: Interactive app selection
# ============================================
select_applications() {
    while true; do
        display_app_menu
        read -p "Enter your choices (comma-separated, e.g., 1,5,16) or A/S/Q: " choices
        
        # Convert to uppercase for single letter commands
        choices_upper=$(echo "$choices" | tr '[:lower:]' '[:upper:]')
        
        case $choices_upper in
            A)
                install_all_apps
                break
                ;;
            S)
                echo -e "${BLUE}Skipping application installation.${NC}"
                break
                ;;
            Q)
                echo -e "${YELLOW}Setup cancelled.${NC}"
                exit 0
                ;;
            *)
                # Process comma-separated selections
                IFS=',' read -ra SELECTIONS <<< "$choices"
                for selection in "${SELECTIONS[@]}"; do
                    # Trim whitespace
                    selection=$(echo "$selection" | tr -d ' ')
                    if [[ "$selection" =~ ^[0-9]+$ ]]; then
                        process_selection "$selection"
                    else
                        echo -e "${RED}Invalid input: $selection${NC}"
                    fi
                done
                
                echo ""
                read -p "Install more applications? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
        esac
    done
}

# ============================================
# Function: Create .env.example template
# ============================================
create_env_template() {
    cat > .env.example << 'EOF'
# ============================================
# Docker Property Automation - Configuration
# ============================================
# Copy this file to .env and customize for your server
# cp .env.example .env
# ============================================

# ============================================
# Server Configuration
# ============================================
# Your server's base domain (e.g., example.com)
BASE_DOMAIN=subdomain.barium.services

# Timezone (e.g., America/New_York, Europe/London, UTC)
TZ=UTC

# User IDs for file permissions (run: id $USER to get these)
PUID=1000
PGID=1000

# Base directory for all container data (relative to project root)
DATA_DIR=./data


# ============================================
# Container Image Versions
# ============================================
# Pin versions for stability, or use 'latest' for auto-updates
# Update these when you want to upgrade services

# Infrastructure
NPM_VERSION=latest
PORTAINER_VERSION=lts
CLOUDFLARED_VERSION=latest
NTP_VERSION=latest

# Media & Entertainment
PLEX_VERSION=latest
FRIGATE_VERSION=stable
JELLYFIN_VERSION=latest

# Arr-Stack
PROWLARR_VERSION=latest
RADARR_VERSION=latest
SONARR_VERSION=latest
OVERSEERR_VERSION=latest

# Download Clients
QBITTORRENT_VERSION=latest
SABNZBD_VERSION=4.5.5

# AI & LLM
OPENWEBUI_VERSION=git-2b26355
LITELLM_VERSION=v1.81.0-stable
PERPLEXICA_VERSION=latest

# Productivity
N8N_VERSION=latest
VAULTWARDEN_VERSION=latest
NEXTCLOUD_AIO_VERSION=latest
STIRLINGPDF_VERSION=latest

# Home & Utility
HOMEBRIDGE_VERSION=v1.11.1
HOMARR_VERSION=v1.51.0
UPTIME_KUMA_VERSION=2.0.2
TANDOOR_VERSION=latest

# Voice & TTS
WHISPER_VERSION=latest
PIPER_VERSION=2.1.2

# Search
SEARXNG_VERSION=latest

# Books
BOOKLORE_VERSION=latest
SHELFMARK_VERSION=latest

# Sync
OBSIDIAN_SYNC_VERSION=3
MINECRAFT_VERSION_TAG=java25

# Databases (internal use)
POSTGRES_VERSION=16-alpine
VALKEY_VERSION=8-alpine
MARIADB_VERSION=latest

# ============================================
# Nginx Proxy Manager
# ============================================
# Ports (leave as default unless you have conflicts)
NPM_HTTP_PORT=80
NPM_ADMIN_PORT=81
NPM_HTTPS_PORT=443

# ============================================
# VaultWarden Configuration
# ============================================
# Full domain URL for VaultWarden
VAULTWARDEN_DOMAIN=https://keys.${BASE_DOMAIN}

# Local port binding (127.0.0.1:PORT:80)
VAULTWARDEN_PORT=5100

# Admin token (generate with: openssl rand -base64 48)
# VAULTWARDEN_ADMIN_TOKEN=

# Signup settings
VAULTWARDEN_SIGNUPS_ALLOWED=true
VAULTWARDEN_INVITATIONS_ALLOWED=true

# ============================================
# n8n Workflow Automation
# ============================================
# Subdomain for n8n (will be: subdomain.BASE_DOMAIN)
N8N_SUBDOMAIN=n8n

# Optional: Enable basic authentication
N8N_BASIC_AUTH_ACTIVE=false
N8N_BASIC_AUTH_USER=
N8N_BASIC_AUTH_PASSWORD=

# Encryption key for credentials storage (generate with: openssl rand -hex 32)
# IMPORTANT: Back this up! If lost, you cannot decrypt stored credentials
# N8N_ENCRYPTION_KEY=

# ============================================
# Minecraft Server
# ============================================
# Server type: VANILLA, PAPER, SPIGOT, BUKKIT, FORGE, FABRIC
MC_TYPE=PAPER
MC_VERSION=LATEST
MC_MEMORY=2G

# Game settings
MC_DIFFICULTY=normal
MC_GAMEMODE=survival
MC_MOTD=A Minecraft Server
MC_MAX_PLAYERS=20
MC_PVP=true
MC_ONLINE_MODE=true
MC_ALLOW_NETHER=true
MC_ENABLE_COMMAND_BLOCK=false
MC_SPAWN_PROTECTION=16
MC_VIEW_DISTANCE=10

# Whitelist & Ops (comma-separated usernames)
MC_WHITELIST=
MC_OPS=

# RCON (remote console) - change password!
MC_ENABLE_RCON=true
MC_RCON_PASSWORD=changeme

# Ports
MC_PORT=25565
MC_RCON_PORT=25575

# ============================================
# LiteLLM Configuration
# ============================================
# Master key for API authentication (generate with: openssl rand -hex 32)
LITELLM_MASTER_KEY=
# Salt key for hashing (generate with: openssl rand -hex 32)
LITELLM_SALT_KEY=

# UI Credentials
LITELLM_UI_USERNAME=admin
LITELLM_UI_PASSWORD=

# Database (internal PostgreSQL)
LITELLM_DB_NAME=litellm
LITELLM_DB_USER=litellm
LITELLM_DB_PASSWORD=

# ============================================
# LLM Provider API Keys
# ============================================
# Add only the keys for providers you use

# OpenAI
OPENAI_API_KEY=

# Anthropic (Claude)
ANTHROPIC_API_KEY=

# Google (Gemini)
GOOGLE_API_KEY=

# Azure OpenAI
AZURE_API_KEY=
AZURE_API_BASE=

# Cohere
COHERE_API_KEY=

# Replicate
REPLICATE_API_TOKEN=

# Hugging Face
HUGGINGFACE_API_KEY=

# Local Ollama (if running on host)
OLLAMA_API_BASE=http://host.docker.internal:11434

# ============================================
# Immich - Photo & Video Management
# ============================================
# Version (use 'release' for latest stable, or pin like 'v1.123.0')
IMMICH_VERSION=release

# Storage locations
# Upload location - can be network share mounted on host
IMMICH_UPLOAD_LOCATION=/path/to/your/photos

# Database location - MUST be local storage, NOT network share!
IMMICH_DB_LOCATION=./Immich/postgres-data

# Database credentials (generate password with: openssl rand -base64 32)
IMMICH_DB_USERNAME=immich
IMMICH_DB_PASSWORD=
IMMICH_DB_NAME=immich

# ============================================
# Homebridge - HomeKit Bridge
# ============================================
# Web UI port (access at http://<host-ip>:PORT)
# NOTE: Homebridge uses host networking for HomeKit discovery
HOMEBRIDGE_PORT=8581

# ============================================
# Shelfmark - Book Download Manager
# ============================================
# Path to your book library (can be network share)
SHELFMARK_BOOKS_PATH=/path/to/books

# Download client path (must match your torrent/usenet client volume)
SHELFMARK_DOWNLOADS_PATH=/path/to/downloads

# ============================================
# BookLore - Book Library Manager
# ============================================
# Path to your book library (can be network share)
BOOKLORE_BOOKS_PATH=/path/to/books

# Database credentials (generate passwords with: openssl rand -base64 24)
BOOKLORE_DB_NAME=booklore
BOOKLORE_DB_USER=booklore
BOOKLORE_DB_PASSWORD=
BOOKLORE_DB_ROOT_PASSWORD=

# Application settings
BOOKLORE_SWAGGER_ENABLED=false
BOOKLORE_FORCE_DISABLE_OIDC=false

# ============================================
# Tandoor Recipes - Recipe Manager
# ============================================
# Secret key for Django (generate with: openssl rand -hex 32)
TANDOOR_SECRET_KEY=

# Database credentials (generate password with: openssl rand -base64 24)
TANDOOR_DB_NAME=tandoor
TANDOOR_DB_USER=tandoor
TANDOOR_DB_PASSWORD=

# Application settings
# Set to 0 after creating your account to disable public registration
TANDOOR_ENABLE_SIGNUP=1

# ============================================
# Arr-Stack (Radarr, Sonarr, etc.)
# ============================================
# Media library paths (can be network shares)
ARR_MOVIES_PATH=/path/to/movies
ARR_TV_PATH=/path/to/tv

# Download client path (must match your torrent/usenet client volume)
ARR_DOWNLOADS_PATH=/path/to/downloads

# ============================================
# Obsidian LiveSync
# ============================================
# CouchDB credentials for Obsidian sync
# Use a strong password - this protects your notes!
OBSIDIAN_SYNC_USER=obsidian
OBSIDIAN_SYNC_PASSWORD=
EOF
}

# ============================================
# Function: Show completion message
# ============================================
show_completion() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ✓ Setup Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Review and edit .env file: nano .env"
    echo "  2. Generate required secrets (use openssl commands in .env)"
    echo "  3. Configure Nginx Proxy Manager at http://your-ip:81"
    echo "     Default login: admin@example.com / changeme"
    echo "  4. Add proxy hosts for your services"
    echo ""
    echo -e "${CYAN}Useful commands:${NC}"
    echo "  ./manage-all.sh status    - Check all services"
    echo "  ./manage-all.sh logs      - View all logs"
    echo "  docker compose logs -f    - View service logs (in service dir)"
echo ""
}

# ============================================
# Main Script Execution
# ============================================

# Check for sudo access
check_sudo

# Step 1: Check Docker installation
echo ""
check_docker

# Step 2: Check Docker Compose
check_docker_compose

# Step 3: Check Docker is running
check_docker_running

# Step 4: Create/update .env file
create_env_file

# Step 5: Create Docker network
create_docker_network

# Step 6: Ask about application installation
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Application Installation${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
read -p "Do you want to install applications now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    select_applications
fi

# Done!
show_completion
