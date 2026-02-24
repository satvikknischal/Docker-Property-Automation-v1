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
echo "  Barium - Property Automation - Setup"
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
# Function: Check .env file
# ============================================
check_env_file() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Environment Configuration${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}No .env file found.${NC}"
        echo ""
        read -p "Have you already configured your .env file? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}✗ .env file not found. Cannot proceed.${NC}"
            echo -e "${YELLOW}  Please copy and configure it first:${NC}"
            echo "    cp .env.example .env"
            echo "    nano .env"
            exit 1
        else
            # Copy .env.example to .env
            if [ -f ".env.example" ]; then
                cp .env.example .env
                echo -e "${GREEN}✓ Created .env from .env.example${NC}"
            else
                echo -e "${RED}✗ .env.example not found! Repository may be incomplete.${NC}"
                exit 1
            fi

            echo ""
            echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║  The .env file has been created from .env.example.             ║${NC}"
            echo -e "${YELLOW}║                                                                ║${NC}"
            echo -e "${YELLOW}║  Please edit the .env file and configure:                      ║${NC}"
            echo -e "${YELLOW}║    • Your domain (BASE_DOMAIN)                                 ║${NC}"
            echo -e "${YELLOW}║    • Timezone (TZ)                                             ║${NC}"
            echo -e "${YELLOW}║    • User IDs (PUID/PGID) — run: id \$USER                     ║${NC}"
            echo -e "${YELLOW}║    • Passwords and secrets (see comments for generation cmds)  ║${NC}"
            echo -e "${YELLOW}║    • Storage paths for media, books, downloads, etc.           ║${NC}"
            echo -e "${YELLOW}║    • API keys for any LLM providers you use                    ║${NC}"
            echo -e "${YELLOW}║                                                                ║${NC}"
            echo -e "${YELLOW}║  Then run this script again to install your containers.        ║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${CYAN}  Edit with:  nano .env${NC}"
            echo ""
            exit 0
        fi
    else
        # .env exists — ask if it's been configured
        echo -e "${GREEN}✓ .env file found${NC}"
        echo ""
        read -p "Have you configured the .env file with your settings? (Y/n): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${YELLOW}Please edit the .env file before continuing:${NC}"
            echo "    nano .env"
            echo ""
            echo -e "${YELLOW}Key items to configure:${NC}"
            echo "    • BASE_DOMAIN, TZ, PUID/PGID"
            echo "    • Passwords and secrets"
            echo "    • Storage paths"
            echo ""
            echo "Run this script again when you're done."
            exit 0
        fi

        echo -e "${GREEN}✓ .env file configured${NC}"
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
    echo "  7) Arr-Stack              - Prowlarr, Radarr, Sonarr, Overseerr, Byparr"
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
    echo -e "${RED}  Q) Quit${NC}"
    echo ""
}

# ============================================
# Function: Pre-create bind mount directories
# ============================================
# Docker auto-creates missing bind mount dirs as root,
# which causes permission issues. This creates them
# as the current user before docker compose runs.
prepare_service_dirs() {
    local app_dir=$1

    case "$app_dir" in
        "Nginx-Proxy-Manager")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            mkdir -p "$SCRIPT_DIR/$app_dir/letsencrypt"
            ;;
        "Portainer")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "Uptime-Kuma")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "Plex")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Frigate")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Arr-Stack/Prowlarr")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Arr-Stack/Radarr")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Arr-Stack/Sonarr")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Arr-Stack/Overseerr")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "qBittorrent")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "SabNZBd")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "OpenWebUI")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "LiteLLM")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            mkdir -p "$SCRIPT_DIR/$app_dir/postgres-data"
            ;;
        "Perplexica")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "SearXNG")
            mkdir -p "$SCRIPT_DIR/$app_dir/searxng"
            mkdir -p "$SCRIPT_DIR/$app_dir/searxng-data"
            mkdir -p "$SCRIPT_DIR/$app_dir/valkey-data"
            ;;
        "VaultWarden")
            mkdir -p "$SCRIPT_DIR/$app_dir/vw-data"
            ;;
        "n8n")
            mkdir -p "$SCRIPT_DIR/$app_dir/n8n_data"
            mkdir -p "$SCRIPT_DIR/$app_dir/local-files"
            ;;
        "StirlingPDF")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            mkdir -p "$SCRIPT_DIR/$app_dir/logs"
            ;;
        "Homarr")
            mkdir -p "$SCRIPT_DIR/$app_dir/appdata"
            ;;
        "Homebridge")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "Immich")
            mkdir -p "$SCRIPT_DIR/$app_dir/model-cache"
            mkdir -p "$SCRIPT_DIR/$app_dir/redis-data"
            ;;
        "Tandoor")
            mkdir -p "$SCRIPT_DIR/$app_dir/tandoor-staticfiles"
            mkdir -p "$SCRIPT_DIR/$app_dir/mediafiles"
            mkdir -p "$SCRIPT_DIR/$app_dir/postgres-data"
            ;;
        "Book-Worms/BookLore")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            mkdir -p "$SCRIPT_DIR/$app_dir/bookdrop"
            mkdir -p "$SCRIPT_DIR/$app_dir/mariadb-data"
            ;;
        "Book-Worms/Shelfmark")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Obsidian-LiveSync")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "Minecraft-Server")
            mkdir -p "$SCRIPT_DIR/$app_dir/data"
            ;;
        "Whisper-STT")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
        "Piper-TTS")
            mkdir -p "$SCRIPT_DIR/$app_dir/config"
            ;;
    esac
}

# ============================================
# Function: Install selected application
# ============================================
install_app() {
    local app_dir=$1
    local app_name=$2

    if [ -d "$app_dir" ]; then
        echo -e "${BLUE}Installing $app_name...${NC}"
        # Pre-create bind mount directories as current user (safety net)
        prepare_service_dirs "$app_dir"
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
            install_app "Arr-Stack/Byparr" "Byparr"
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
        read -p "Enter your choices (comma-separated, e.g., 1,5,16) or A/Q: " choices

        # Convert to uppercase for single letter commands
        choices_upper=$(echo "$choices" | tr '[:lower:]' '[:upper:]')

        case $choices_upper in
            A)
                install_all_apps
                break
                ;;
            Q)
                echo -e "${YELLOW}Exiting.${NC}"
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
# Function: Show completion message
# ============================================
show_completion() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ✓ Setup Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Configure Nginx Proxy Manager at http://your-ip:81"
    echo "     Default login: admin@example.com / changeme"
    echo "  2. Add proxy hosts for your services"
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

# Step 4: Check .env file is configured
check_env_file

# Step 5: Create Docker network
create_docker_network

# Step 6: Select and install applications
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Application Installation${NC}"
echo -e "${CYAN}============================================${NC}"
select_applications

# Done!
show_completion
