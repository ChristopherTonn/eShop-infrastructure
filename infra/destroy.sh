#!/bin/bash

# eShop Cleanup Script - .NET Aspire Version
# Beendet Aspire-Prozesse und räumt lokale Ressourcen auf

set -e

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧹 eShop Cleanup - Stopping Aspire Services${NC}"
echo "==========================================="
echo ""

# 1. Stoppe Aspire Prozess
echo -e "${YELLOW}📋 Step 1: Stop Aspire Process${NC}"

if [[ -f /tmp/eshop-aspire.pid ]]; then
    ASPIRE_PID=$(cat /tmp/eshop-aspire.pid)
    if kill -0 "$ASPIRE_PID" 2>/dev/null; then
        echo "  🛑 Stopping Aspire process (PID: $ASPIRE_PID)..."
        kill "$ASPIRE_PID"
        sleep 2
        
        # Force kill falls noch aktiv
        if kill -0 "$ASPIRE_PID" 2>/dev/null; then
            echo "  ⚠️  Force killing process..."
            kill -9 "$ASPIRE_PID"
        fi
        echo "  ✅ Aspire process stopped"
    else
        echo "  ℹ️  Process not running"
    fi
    rm -f /tmp/eshop-aspire.pid
else
    echo "  ℹ️  No PID file found. Searching for eShop.AppHost processes..."
    if pgrep -f "eShop.AppHost" > /dev/null; then
        pkill -f "eShop.AppHost" || true
        sleep 1
        echo "  ✅ eShop.AppHost processes terminated"
    else
        echo "  ℹ️  No eShop processes found"
    fi
fi

# 2. Cleanup Logs
echo -e "${YELLOW}📋 Step 2: Cleanup Logs${NC}"
if [[ -f /tmp/eshop-aspire.log ]]; then
    rm -f /tmp/eshop-aspire.log
    echo "  ✅ Log file removed"
else
    echo "  ℹ️  No log file found"
fi

# 3. Verify Port Cleanup
echo -e "${YELLOW}📋 Step 3: Verify Port Cleanup${NC}"
echo "  ℹ️  Checking if ports are free..."

for port in 5000 15000 5432 6379 5672; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ⚠️  Port $port is still in use"
    else
        echo "  ✅ Port $port is free"
    fi
done

# 4. Cleanup Docker Containers (if running)
echo -e "${YELLOW}📋 Step 4: Docker Container Cleanup (Optional)${NC}"
if command -v docker >/dev/null 2>&1; then
    ASPIRE_CONTAINERS=$(docker ps -a -q -f label=aspire 2>/dev/null || echo "")
    if [[ -n "$ASPIRE_CONTAINERS" ]]; then
        echo "  🐳 Stopping Aspire Docker containers..."
        echo "$ASPIRE_CONTAINERS" | xargs -r docker stop 2>/dev/null || true
        echo "$ASPIRE_CONTAINERS" | xargs -r docker rm 2>/dev/null || true
        echo "  ✅ Docker containers cleaned up"
    else
        echo "  ℹ️  No Aspire containers found"
    fi
else
    echo "  ℹ️  Docker not installed"
fi

# 5. Optional: Clean build artifacts
echo -e "${YELLOW}📋 Step 5: Build Artifacts (Optional)${NC}"
echo "  💡 To clean build artifacts, run:"
echo "     dotnet clean ../src/eShop.sln"
echo "     find ../src -type d -name 'bin' -o -name 'obj' | xargs rm -rf"

# 6. Cleanup Summary
echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ eShop Cleanup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}✅ Cleanup Actions:${NC}"
echo "  ✓ Aspire process stopped"
echo "  ✓ Log files cleaned up"
echo "  ✓ Ports verified"
echo "  ✓ Docker containers cleaned up"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  • To restart: ./deploy-v2.sh"
echo "  • To see logs: tail -f /tmp/eshop-aspire.log"
echo "  • To clean build: dotnet clean ../src/eShop.sln"
echo ""
echo -e "${GREEN}🧹 All cleanup completed!${NC}"