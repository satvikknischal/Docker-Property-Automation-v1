#!/bin/bash

# Docker Property Automation - Service Management Script
# Usage: ./manage-all.sh [command]
# Commands: up, down, restart, pull, logs, ps, status

COMMAND=${1:-status}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory (for finding root .env)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Run ./setup.sh first to create the configuration."
    exit 1
fi

echo "============================================"
echo "Docker Property Automation - Service Manager"
echo "Command: $COMMAND"
echo "============================================"
echo ""

# Function to run docker compose with env file
dc() {
    docker compose --env-file "$ENV_FILE" "$@"
}

# Find all compose files (including nested directories like Arr-Stack/*)
find . -maxdepth 3 \( -name "docker-compose.yml" -o -name "compose.yml" \) | sort | while read compose_file; do
    service_dir=$(dirname "$compose_file")
    service_name=$(basename "$service_dir")
    
    # Skip if in root or hidden directories
    if [[ "$service_dir" == "." ]] || [[ "$service_name" == .* ]]; then
        continue
    fi
    
    echo -e "${YELLOW}Processing: $service_name${NC}"
    cd "$service_dir"
    
    case $COMMAND in
        up)
            dc up -d
            ;;
        down)
            dc down
            ;;
        restart)
            dc restart
            ;;
        pull)
            dc pull
            ;;
        logs)
            dc logs --tail=50
            ;;
        ps)
            dc ps
            ;;
        status)
            if dc ps 2>/dev/null | grep -q "Up\|running"; then
                echo -e "${GREEN}✓ Running${NC}"
            else
                echo -e "${RED}✗ Not running${NC}"
            fi
            ;;
        *)
            echo "Unknown command: $COMMAND"
            echo "Usage: $0 [up|down|restart|pull|logs|ps|status]"
            exit 1
            ;;
    esac
    
    cd "$SCRIPT_DIR"
    echo ""
done

if [ "$COMMAND" == "status" ]; then
    echo "============================================"
    echo "Summary: Run 'docker compose ps' in each service directory for details"
fi

