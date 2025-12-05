# 💻 Local Development Setup

Complete guide for setting up eShop development environment on your machine.

**Navigation:** [← ASPIRE Guide](ASPIRE_QUICK_START.md) | [Up ↑](../INDEX.md) | [Next: Troubleshooting →](TROUBLESHOOTING.md)

## 📋 System Requirements

### Minimum Hardware

| Resource | Requirement |
|----------|-------------|
| **CPU** | 4 cores (Intel/AMD) |
| **RAM** | 8GB (16GB recommended) |
| **Disk** | 20GB free space |
| **OS** | Windows, macOS, or Linux |

### Software Prerequisites

```bash
# 1. .NET SDK 9.0
dotnet --version
# Output: .NET 9.0.x

# 2. Docker Desktop 20.0+
docker --version
# Output: Docker version 20.0+

# 3. Git 2.0+
git --version
# Output: git version 2.x.x

# 4. Optional: Visual Studio Code
code --version
# Output: 1.x.x
```

---

## 🚀 Quick Setup (15 minutes)

### Step 1: Clone Repository

```bash
git clone https://github.com/dotnet-architecture/eShop.git
cd eShop
```

### Step 2: Verify Tools

```bash
# Check all required tools
dotnet --version          # Should be 9.0+
docker --version          # Should be 20.0+
git --version             # Should be 2.0+
docker ps                 # Should show "CONTAINER ID" header
```

### Step 3: Start Development Environment

```bash
cd codebase

# Option A: Using .NET Aspire (Recommended)
dotnet run --project src/eShop.AppHost

# Option B: Using Docker Compose (Alternative)
docker-compose up -d

# Option C: Manual (not recommended)
# See "Manual Service Startup" section below
```

### Step 4: Access Services

```bash
# Aspire Dashboard
http://localhost:15213

# Web Application
http://localhost:5173

# API Gateway
http://localhost:8000
```

---

## 🔧 Development Environments

### Environment A: .NET Aspire (Recommended for Developers)

**Best for:** Local development, debugging, testing

**Advantages:**
✅ Integrated dashboard (metrics, logs, debugging)  
✅ Automatic container management  
✅ Hot reload support  
✅ Easy service configuration  

**Setup:**
```bash
cd codebase
dotnet run --project src/eShop.AppHost
```

**Access Dashboard:**
```
http://localhost:15213
```

---

### Environment B: Docker Compose (Alternative)

**Best for:** Simulating production environment

**Advantages:**
✅ Matches production architecture  
✅ Full containerization  
✅ Easy to share with team  

**Setup:**
```bash
cd codebase
docker-compose -f docker-compose.yml up -d
```

**Check Services:**
```bash
docker-compose ps
```

---

### Environment C: Manual (Advanced)

**Best for:** Specific debugging scenarios

**Setup:**
```bash
cd codebase

# Terminal 1: Start PostgreSQL
docker run -d \
  -e POSTGRES_USER=eshop \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  postgres:15

# Terminal 2: Start Redis
docker run -d \
  -p 6379:6379 \
  redis:7

# Terminal 3: Start RabbitMQ
docker run -d \
  -p 5672:5672 \
  -p 15672:15672 \
  rabbitmq:3-management

# Terminal 4: Start Basket API
dotnet run --project src/Basket.API

# Terminal 5: Start Catalog API
dotnet run --project src/Catalog.API

# ... (repeat for other services)
```

---

## 🔌 Database Setup

### PostgreSQL Connection

```bash
# Connection string (default)
User ID=eshop;Password=secret;Server=localhost;Port=5432;Database=catalogdb

# Using psql CLI
psql -h localhost -U eshop -d catalogdb

# Verify connection
\dt  # List tables
\l   # List databases
```

### Entity Framework Migrations

```bash
cd codebase

# Apply all migrations
dotnet ef database update --project src/Catalog.API

# Revert to previous migration
dotnet ef database update <MigrationName> --project src/Catalog.API

# Create new migration
dotnet ef migrations add <MigrationName> --project src/Catalog.API
```

### Seed Sample Data

```bash
# Data is automatically seeded on service startup
# To reseed:

# 1. Delete database
psql -U eshop -c "DROP DATABASE catalogdb;"

# 2. Restart service (migrations will recreate and seed)
dotnet run --project src/Catalog.API
```

---

## 🐛 Debugging

### Debug in VS Code

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Basket.API",
      "type": "coreclr",
      "request": "launch",
      "program": "${workspaceFolder}/codebase/src/Basket.API/bin/Debug/net9.0/Basket.API.dll",
      "args": [],
      "cwd": "${workspaceFolder}/codebase/src/Basket.API",
      "stopAtEntry": false,
      "console": "internalConsole",
      "internalConsoleOptions": "neverOpen"
    }
  ]
}
```

### Debug Aspire Services

```bash
# 1. Start Aspire in debug mode
dotnet run --project src/eShop.AppHost --configuration Debug

# 2. In VS Code, attach debugger to service
# View → Run and Debug → Select service from dropdown

# 3. Set breakpoints in service code
# Breakpoints will be hit when service processes requests
```

### View Request Logs

```bash
# Enable detailed logging
# In appsettings.Development.json:
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Debug",
      "MassTransit": "Debug"
    }
  }
}
```

---

## 🧪 Testing Locally

### Unit Tests

```bash
cd codebase

# Run all tests
dotnet test

# Run specific project
dotnet test tests/Basket.UnitTests/

# Run specific test
dotnet test --filter "FullyQualifiedName~BasketServiceTests.GetBasketTest"

# With coverage
dotnet test /p:CollectCoverage=true /p:CoverageFormat=opencover
```

### Integration Tests

```bash
# Tests that require running services
# Prerequisites: Start Aspire first

cd codebase
dotnet test tests/Catalog.FunctionalTests/
```

### E2E Tests

```bash
# Browser-based tests using Playwright
# Prerequisites: Start Aspire first

cd codebase/e2e

# Install dependencies
npm install

# Run tests
npx playwright test

# Run in headed mode (see browser)
npx playwright test --headed

# Debug tests
npx playwright test --debug
```

---

## 🚨 Common Issues & Solutions

### Issue: "Port 5432 already in use"

**Cause:** Another PostgreSQL instance is running

**Solution:**
```bash
# Find process using port 5432
lsof -i :5432

# Kill the process
kill -9 <PID>

# Or stop the service
brew services stop postgresql  # macOS
# or: systemctl stop postgresql  # Linux
# or: Services app (Windows)
```

### Issue: "Docker daemon is not running"

**Cause:** Docker Desktop not started

**Solution:**
```bash
# macOS
open /Applications/Docker.app

# Windows/Linux: Start Docker Desktop from Applications
# Or via CLI: systemctl start docker (Linux)
```

### Issue: Service fails to connect to database

**Cause:** Connection string incorrect or database not ready

**Solution:**
```bash
# Test connection
psql -h localhost -U eshop -d catalogdb

# Check connection string in appsettings.Development.json
cat src/Catalog.API/appsettings.Development.json

# Ensure database exists
psql -c "CREATE DATABASE catalogdb;" -U postgres
```

### Issue: "Out of disk space"

**Cause:** Docker images/containers accumulating

**Solution:**
```bash
# Clean up Docker
docker system prune -a --volumes

# Or remove specific containers/images
docker rm -f <CONTAINER_ID>
docker rmi <IMAGE_ID>
```

---

## 📚 Development Workflow

### Create a Feature Branch

```bash
git checkout -b feature/my-feature
```

### Make Changes

```bash
# Edit code in src/ or tests/
# Aspire will detect changes and recompile

# Or manually:
dotnet build
```

### Run Tests

```bash
dotnet test tests/
```

### Commit Changes

```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

### Create Pull Request

```bash
# Via GitHub UI or CLI
gh pr create --title "Add new feature" --body "Description"
```

---

## 📊 Performance Tuning

### Reduce Memory Usage

```bash
# Limit Docker resources
# In Docker Desktop:
# Settings → Resources → Memory: 4GB (or less)
```

### Speed Up Builds

```bash
# Use incremental build
dotnet build --no-restore

# Clean before full rebuild
dotnet clean
dotnet build
```

### Parallel Testing

```bash
# Run tests in parallel
dotnet test --parallel
```

---

## 🔐 Environment Variables

### Development Configuration

```bash
# .env file (create in codebase/)
ASPNETCORE_ENVIRONMENT=Development
ASPNETCORE_URLS=http://localhost:8000
ConnectionStrings__DefaultConnection=User ID=eshop;Password=secret;Server=localhost;Port=5432;Database=catalogdb
```

### Load Environment Variables

```bash
# On Linux/macOS
export $(cat .env | xargs)

# On Windows PowerShell
Get-Content .env | ForEach-Object { $_.Split('=') | Set-Item "env:\$($_[0])" ($_[1]) }
```

---

## 📚 Related Documentation

- [Aspire Quick Start](ASPIRE_QUICK_START.md) - Running with Aspire
- [Getting Started](../GETTING_STARTED.md) - First steps
- [Architecture](../ARCHITECTURE.md) - System design
- [Contributing Guidelines](CONTRIBUTING.md) - Code standards

---

**Last updated:** December 2025
