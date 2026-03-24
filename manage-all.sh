#!/bin/bash

# Docker Property Automation - Service Management Script
# Usage: ./manage-all.sh [command]
# Commands: up, down, restart, pull, logs, ps, status

COMMAND=${1:-status}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
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

# Validate command
case $COMMAND in
    up|down|restart|pull|logs|ps|status)
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Usage: $0 [up|down|restart|pull|logs|ps|status]"
        exit 1
        ;;
esac

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Docker Property Automation - Service Manager${NC}"
echo -e "${CYAN}Command: $COMMAND${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Collect all compose files into an array (avoids subshell piping issues)
COMPOSE_FILES=()
while IFS= read -r -d '' file; do
    COMPOSE_FILES+=("$file")
done < <(find "$SCRIPT_DIR" -maxdepth 3 \( -name "docker-compose.yml" -o -name "compose.yml" \) -print0 | sort -z)

RUNNING=0
STOPPED=0

for compose_file in "${COMPOSE_FILES[@]}"; do
    service_dir=$(dirname "$compose_file")
    # Get relative path from script dir for display
    rel_path="${service_dir#$SCRIPT_DIR/}"
    service_name=$(basename "$service_dir")

    # Skip if in root or hidden directories
    if [[ "$service_dir" == "$SCRIPT_DIR" ]] || [[ "$service_name" == .* ]]; then
        continue
    fi

    cd "$service_dir"

    case $COMMAND in
        up)
            echo -e "${YELLOW}Starting: $rel_path${NC}"
            docker compose --env-file "$ENV_FILE" up -d
            ;;
        down)
            echo -e "${YELLOW}Stopping: $rel_path${NC}"
            docker compose --env-file "$ENV_FILE" down
            ;;
        restart)
            echo -e "${YELLOW}Restarting: $rel_path${NC}"
            docker compose --env-file "$ENV_FILE" restart
            ;;
        pull)
            echo -e "${YELLOW}Pulling: $rel_path${NC}"
            docker compose --env-file "$ENV_FILE" pull
            ;;
        logs)
            echo -e "${YELLOW}=== $rel_path ===${NC}"
            docker compose --env-file "$ENV_FILE" logs --tail=50
            ;;
        ps)
            echo -e "${YELLOW}=== $rel_path ===${NC}"
            docker compose --env-file "$ENV_FILE" ps
            ;;
        status)
            if docker compose --env-file "$ENV_FILE" ps 2>/dev/null | grep -q "Up\|running"; then
                echo -e "  ${GREEN}✓${NC} $rel_path"
                ((RUNNING++))
            else
                echo -e "  ${RED}✗${NC} $rel_path"
                ((STOPPED++))
            fi
            ;;
    esac

    cd "$SCRIPT_DIR"

    # Add spacing for verbose commands
    if [[ "$COMMAND" != "status" ]]; then
        echo ""
    fi
done

if [ "$COMMAND" == "status" ]; then
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "  ${GREEN}Running: $RUNNING${NC}  |  ${RED}Stopped: $STOPPED${NC}"
    echo -e "${CYAN}============================================${NC}"
fi
