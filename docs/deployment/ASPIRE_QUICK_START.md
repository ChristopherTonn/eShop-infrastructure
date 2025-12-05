# 🚀 .NET Aspire Quick Start Guide

Fast local development setup for eShop microservices using .NET Aspire orchestration.

**Navigation:** [← Back](../GETTING_STARTED.md) | [Up ↑](../INDEX.md) | [Next: Local Dev →](LOCAL_DEVELOPMENT.md)

## 📋 Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| .NET SDK | 9.0+ | `dotnet --version` |
| Docker Desktop | 20.0+ | `docker --version` |
| Visual Studio Code | Latest | `code --version` |
| Git | 2.0+ | `git --version` |

Optional but recommended:
- **Aspire Dashboard**: Built-in to .NET 9
- **Docker Compose**: For container orchestration (included in Docker Desktop)

---

## 🚀 Installation (5 minutes)

### 1. Clone Repository

```bash
git clone https://github.com/dotnet-architecture/eShop.git
cd eShop/codebase
```

### 2. Restore NuGet Packages

```bash
# From codebase directory
dotnet restore

# This downloads all dependencies for:
# - 9 microservices
# - 4 test projects
# - Shared libraries
```

### 3. Start Aspire Dashboard & Services

```bash
# Run the Aspire AppHost
dotnet run --project src/eShop.AppHost

# Output should show:
# ✅ Aspire dashboard running on http://localhost:15213
# ✅ Services starting up...
# ✅ Ready to accept requests
```

### 4. Verify Services Are Running

Open **[Aspire Dashboard](http://localhost:15213)** and check:

```
✅ basket-api        - Ready
✅ catalog-api       - Ready
✅ identity-api      - Ready
✅ ordering-api      - Ready
✅ webhooks-api      - Ready
✅ web               - Ready
✅ postgres          - Ready (database)
✅ rabbitmq          - Ready (message broker)
✅ redis             - Ready (cache)
```

---

## 🎯 Quick Development Workflow

### View All Services

```bash
# In Aspire Dashboard, click Services tab
# Shows logs, metrics, and health status
```

### Access Web Application

```bash
http://localhost:5173        # Frontend (Vite dev server)
```

### Access APIs

```bash
# API Base URL
http://localhost:8000

# Examples:
curl http://localhost:8000/catalog/api/v1/items
curl http://localhost:8000/basket/api/v1/basket/1
curl http://localhost:8000/ordering/api/v1/orders
```

### View Logs

```bash
# In Aspire Dashboard:
1. Click on a service (e.g., "basket-api")
2. View Console tab for real-time logs
3. Filter by log level (Info, Warning, Error)
```

### Debug Services

```bash
# In VS Code:
1. Click Run & Debug sidebar
2. Select "eShop.AppHost (Aspire)"
3. Set breakpoints in service code
4. Breakpoints will be hit when services handle requests
```

### Monitor Performance

```bash
# In Aspire Dashboard:
1. Click Metrics tab
2. View real-time CPU/Memory/Network usage
3. Check request latency (p50, p95, p99)
```

---

## 🗄️ Database Management

### Reset Database

```bash
# Stop Aspire
Ctrl+C

# Reset PostgreSQL data
rm -rf ~/.aspire-data/postgres

# Restart Aspire
dotnet run --project src/eShop.AppHost
```

### Connect to Database Directly

```bash
# Get PostgreSQL connection string from Aspire
# In Dashboard → postgres service → Bindings tab

# Using psql CLI:
psql -h localhost -U eshop -d catalogdb
```

### View Database Migrations

```bash
# Migrations run automatically on service startup
# To revert:
dotnet ef database update 0 --project src/Catalog.API

# To apply latest:
dotnet ef database update --project src/Catalog.API
```

---

## 🔧 Common Development Tasks

### Add a New NuGet Package

```bash
cd src/Basket.API
dotnet add package Newtonsoft.Json

# Aspire will automatically recompile on restart
```

### Modify Service Configuration

```bash
# Edit appsettings.Development.json
vim src/Catalog.API/appsettings.Development.json

# Changes apply immediately on restart
```

### Run Unit Tests

```bash
cd codebase

# All tests
dotnet test

# Specific project
dotnet test tests/Basket.UnitTests/

# Specific test class
dotnet test --filter FullyQualifiedName~BasketServiceTests
```

### Run E2E Tests

```bash
cd codebase/e2e

# Install dependencies
npm install

# Run tests (requires Aspire running)
npx playwright test

# View results
npx playwright show-report
```

---

## 🚨 Troubleshooting

### Port Already in Use

```bash
# Find process using port 15213
lsof -i :15213

# Kill the process
kill -9 <PID>

# Or change Aspire port in AppHost
# src/eShop.AppHost/Program.cs:
// builder.AddAspireApp().WithHttpsPort(15213);
```

### Docker Connection Issues

```bash
# Make sure Docker Desktop is running
docker ps

# If not, start Docker:
open /Applications/Docker.app  # macOS
# Or restart Docker Desktop on Windows/Linux
```

### Service Fails to Start

```bash
# Check logs in Aspire Dashboard
# Services tab → Click failing service → Console tab

# Common causes:
- Port already in use → Kill conflicting process
- Missing .NET SDK → Install .NET 9
- Out of disk space → Clean Docker images: docker system prune
```

### Database Connection Error

```
Connection refused: postgres:5432
```

Solutions:
```bash
# 1. Ensure postgres service is running in Aspire
# 2. Check connection string in appsettings.Development.json
# 3. Reset database (see Database Management section above)
```

### Memory Issues

```bash
# If Aspire uses too much memory:
# 1. Stop Aspire: Ctrl+C
# 2. Clean Docker: docker system prune -a
# 3. Restart: dotnet run --project src/eShop.AppHost
```

---

## 🔍 Advanced Development

### Change Service Port

```bash
# In src/eShop.AppHost/Program.cs:
builder
    .AddProject<Projects.Basket_API>("basket-api")
    .WithHttpPort(8001)  // Change from 8000 to 8001
    .WithEndpoint(port: 8001, scheme: "http")
    .WithBuild();
```

### Add Environment Variables

```bash
# In src/eShop.AppHost/Program.cs:
builder
    .AddProject<Projects.Catalog_API>("catalog-api")
    .WithEnvironment("LOG_LEVEL", "Debug")
    .WithEnvironment("CACHE_TTL", "3600");
```

### Enable Request Logging

```bash
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

## 📚 Related Documentation

- [Getting Started](../GETTING_STARTED.md)
- [Local Development Setup](LOCAL_DEVELOPMENT.md)
- [CI/CD & Automation](../CI-CD.md)
- [Architecture](../ARCHITECTURE.md)
- [.NET Aspire Official Docs](https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview)

---

**Last updated:** December 2025
