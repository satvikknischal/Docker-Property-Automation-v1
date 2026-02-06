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

echo "============================================"
echo "Docker Property Automation - Service Manager"
echo "Command: $COMMAND"
echo "============================================"
echo ""

# Find all compose files
find . -maxdepth 2 \( -name "docker-compose.yml" -o -name "compose.yml" \) | while read compose_file; do
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
            docker compose up -d
            ;;
        down)
            docker compose down
            ;;
        restart)
            docker compose restart
            ;;
        pull)
            docker compose pull
            ;;
        logs)
            docker compose logs --tail=50 -f
            ;;
        ps)
            docker compose ps
            ;;
        status)
            if docker compose ps | grep -q "Up"; then
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
    
    cd - > /dev/null
    echo ""
done

if [ "$COMMAND" == "status" ]; then
    echo "============================================"
    echo "Summary: Run 'docker compose ps' in each service directory for details"
fi

