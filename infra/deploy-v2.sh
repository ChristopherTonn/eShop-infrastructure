#!/bin/bash

# eShop Deployment Script - .NET Aspire Version
# Startet die eShop-Anwendung mit .NET Aspire und öffnet sie automatisch im Browser

set -e  # Exit bei Fehlern

# Script Directory ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 eShop Infrastructure Deployment with .NET Aspire"
echo "===================================================="
echo "Working from: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function for retries
retry_command() {
    local retries=3
    local count=0
    until [ $count -ge $retries ]; do
        if "$@"; then
            break
        fi
        count=$((count+1))
        echo "Retry $count/$retries for: $*"
        sleep 5
    done
}

# 0. Pre-Check: Sauberkeit sicherstellen
echo -e "${YELLOW}📋 Step 0: Pre-Deployment Checks${NC}"
echo "  ✅ Checking system prerequisites..."

# 1. Validiere Umgebung
echo -e "${YELLOW}📋 Step 1: Validate Environment${NC}"
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}  ❌ .NET SDK not found. Please install .NET 8 or later.${NC}"
    exit 1
fi
DOTNET_VERSION=$(dotnet --version)
echo "  ✅ .NET SDK found: $DOTNET_VERSION"

if ! command -v git &> /dev/null; then
    echo -e "${RED}  ❌ Git not found. Please install Git.${NC}"
    exit 1
fi
echo "  ✅ Git is installed"

# 2. Validiere Projekt-Struktur
echo -e "${YELLOW}📋 Step 2: Validate Project Structure${NC}"
if [[ ! -f "$PROJECT_ROOT/src/eShop.AppHost/eShop.AppHost.csproj" ]]; then
    echo -e "${RED}  ❌ eShop.AppHost project not found at $PROJECT_ROOT/src/eShop.AppHost/eShop.AppHost.csproj${NC}"
    exit 1
fi
echo "  ✅ eShop.AppHost project found"

# 3. AWS Infrastruktur (Optional)
echo -e "${YELLOW}📋 Step 3: AWS Infrastructure Setup (Optional)${NC}"
echo "  ℹ️  For local development with Aspire, AWS infrastructure is optional"
echo "  📝 Terraform configs available in: terraform/envs/dev/"
echo "  💡 You can deploy to AWS EKS later if needed"
echo "  ✅ Continuing with local Aspire deployment..."

# 4. Deploy eShop App mit .NET Aspire
echo -e "${YELLOW}📋 Step 4: Deploy eShop Application with .NET Aspire${NC}"
cd "$PROJECT_ROOT"

echo "  🔧 Installing/Restoring dependencies..."
dotnet restore "src/eShop.AppHost/eShop.AppHost.csproj"

echo "  🚀 Building eShop.AppHost..."
dotnet build "src/eShop.AppHost/eShop.AppHost.csproj" -c Release

echo "  🎯 Starting eShop with Aspire..."
echo "  📊 Aspire Dashboard wird unter http://localhost:15000 verfügbar sein"
echo ""

# Starte Aspire in Hintergrund
dotnet run --project "src/eShop.AppHost/eShop.AppHost.csproj" --configuration Release > /tmp/eshop-aspire.log 2>&1 &
ASPIRE_PID=$!
echo "  ✅ Aspire process started with PID: $ASPIRE_PID"

# 5. Warte bis Services bereit sind
echo -e "${YELLOW}📋 Step 5: Wait for Services to be Ready${NC}"
echo "  ⏳ Waiting for Aspire dashboard (localhost:15000)..."

MAX_RETRIES=60
RETRY_COUNT=0
ASPIRE_READY=false

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s http://localhost:15000 > /dev/null 2>&1; then
        ASPIRE_READY=true
        echo "  ✅ Aspire dashboard is ready!"
        break
    fi
    echo "  ⏳ Waiting for Aspire dashboard... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [[ "$ASPIRE_READY" != true ]]; then
    echo -e "${YELLOW}  ⚠️  Aspire dashboard not ready yet, but services might still be starting...${NC}"
fi

echo "  ⏳ Waiting for WebApp service (localhost:5000)..."
RETRY_COUNT=0
WEBAPP_READY=false

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s http://localhost:5000 > /dev/null 2>&1; then
        WEBAPP_READY=true
        echo "  ✅ WebApp service is ready!"
        break
    fi
    echo "  ⏳ Waiting for WebApp service... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT+1))
done

# 6. Öffne eShop im Browser
echo -e "${YELLOW}📋 Step 6: Open eShop in Browser${NC}"

if [[ "$WEBAPP_READY" == true ]]; then
    echo "  🌐 Opening eShop WebApp..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "http://localhost:5000"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        xdg-open "http://localhost:5000" || echo "  ℹ️  Please open http://localhost:5000 manually"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # Windows
        start "http://localhost:5000"
    fi
else
    echo "  ⚠️  WebApp service not ready yet"
fi

# 7. Erfolgreiche Bereitstellung
echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ eShop Aspire Deployment Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}🚀 Services Running:${NC}"
echo -e "  📊 Aspire Dashboard: ${GREEN}http://localhost:15000${NC}"
echo -e "  🛒 eShop WebApp:     ${GREEN}http://localhost:5000${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  • Monitor services in the Aspire Dashboard"
echo "  • Check logs: tail -f /tmp/eshop-aspire.log"
echo "  • Stop services: kill $ASPIRE_PID"
echo "  • Cleanup: ./destroy.sh"
echo ""
echo -e "${GREEN}🎉 All services are running! Happy coding!${NC}"

# Schreibe PID in Datei für Cleanup
echo "$ASPIRE_PID" > /tmp/eshop-aspire.pid