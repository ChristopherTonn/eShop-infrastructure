# 🚨 Troubleshooting Guide

Common issues and solutions for eShop development and deployment.

**Navigation:** [← Local Dev](LOCAL_DEVELOPMENT.md) | [Up ↑](../INDEX.md) | [Next: Environments →](ENVIRONMENTS_AND_SECRETS.md)

## 🔴 Critical Issues

### Services Won't Start

**Error:** `Unhandled exception. System.Net.Sockets.SocketException (111): Connection refused`

**Cause:** Dependencies (PostgreSQL, Redis, RabbitMQ) not running

**Solution:**

```bash
# Option 1: Using Aspire (recommended)
cd codebase
dotnet run --project src/eShop.AppHost
# Aspire manages all dependencies

# Option 2: Using Docker Compose
cd codebase
docker-compose up -d

# Verify dependencies are running
docker ps
# Should show: postgres, redis, rabbitmq containers
```

---

### Build Fails with CS1660

**Error:** `CS1660: Cannot use lambda expression as an argument to a dynamically dispatched operation`

**Cause:** .NET 9 incompatibility in OpenAPI configuration

**Solution:**

```bash
# Ensure you're using .NET 9
dotnet --version
# Output should be: 9.0.x

# Update OpenAPI extensions in:
# src/eShop.ServiceDefaults/OpenApiOptionsExtensions.cs

# Remove lambda-based transformers (NET 10+ only)
# Replace with NET 9 compatible code
```

**Code Fix:**

```csharp
// ❌ Wrong (NET 10+ only)
options.AddOperationTransformer((operation, context, cancellationToken) => {
    // transformation code
});

// ✅ Correct (NET 9)
// Use non-transformer approaches instead
ApplySecuritySchemeDefinitions();
```

---

### Database Connection Timeout

**Error:** `The wait operation timed out. Connection timeout expired. The timeout period elapsed during the connection pool getting an object from the pool`

**Cause:** PostgreSQL not accessible or wrong connection string

**Solution:**

```bash
# Step 1: Verify PostgreSQL is running
docker ps | grep postgres

# Step 2: Test connection
psql -h localhost -U eshop -d catalogdb

# Step 3: Check connection string in appsettings.Development.json
cat src/Catalog.API/appsettings.Development.json | grep ConnectionString

# Step 4: Verify firewall allows port 5432
netstat -an | grep 5432
```

---

## 🟡 Common Issues

### Port Already in Use

**Error:** `System.IO.IOException: Failed to bind to address http://127.0.0.1:8000`

**Cause:** Another process using the same port

**Solution:**

```bash
# Find process using port
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or change port in appsettings.json:
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:8001"
      }
    }
  }
}
```

---

### Docker Container Exits Immediately

**Error:** Container in `Exited` state with exit code 1

**Cause:** Application error or missing dependencies

**Solution:**

```bash
# Check container logs
docker logs <CONTAINER_ID>

# Rebuild container
docker-compose down -v
docker-compose up --build -d

# Check specific service logs
docker-compose logs basket-api
```

---

### NuGet Package Restore Fails

**Error:** `NuGet restore failed. Access denied` or `Package not found`

**Cause:** Network issues, authentication, or invalid package source

**Solution:**

```bash
# Clear NuGet cache
dotnet nuget locals all --clear

# Restore packages
dotnet restore --force

# Check nuget.config for package sources
cat nuget.config

# Verify network connectivity
curl -I https://api.nuget.org/v3/index.json
```

---

### Test Execution Hangs

**Error:** Tests appear to hang with no output

**Cause:** Tests waiting for service timeout or deadlock

**Solution:**

```bash
# Run tests with timeout
dotnet test --timeout 30000  # 30 seconds

# Run specific test
dotnet test --filter "TestClassName.MethodName"

# Run with verbose logging
dotnet test --logger console --verbosity detailed
```

---

## 🔵 Kubernetes Issues

### Pod Won't Start (ImagePullBackOff)

**Error:** Pod status shows `ImagePullBackOff`

**Cause:** Docker image not found in ECR or authentication failed

**Solution:**

```bash
# Verify image exists in ECR
aws ecr describe-images \
  --repository-name basket-api \
  --region eu-central-1

# Check ECR authentication
kubectl get secret -n eshop

# Rebuild and push image
docker build -t basket-api:latest src/Basket.API
docker tag basket-api:latest \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:latest
docker push \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:latest

# Redeploy
kubectl rollout restart deployment/basket-api -n eshop
```

---

### Service Endpoints Empty

**Error:** `kubectl get endpoints` shows no endpoints for service

**Cause:** Pods not running or service selector doesn't match pod labels

**Solution:**

```bash
# Check pod status
kubectl get pods -n eshop

# Verify pod labels match service selector
kubectl get pods -n eshop -L app,version

# Check service selector
kubectl get svc basket-api -o yaml | grep -A 2 selector

# Describe service for events
kubectl describe svc basket-api -n eshop
```

---

### Out of Memory

**Error:** Pod killed with `OOMKilled`

**Cause:** Pod exceeds memory limit

**Solution:**

```bash
# Check current memory limits
kubectl describe pod <POD_NAME> -n eshop

# Check actual memory usage
kubectl top pods -n eshop

# Increase memory limit
kubectl patch deployment basket-api \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"basket-api","resources":{"limits":{"memory":"512Mi"}}}]}}}}' \
  -n eshop

# Or update in Helm values and redeploy
helm upgrade eshop ./helm/eshop \
  --set resources.limits.memory=512Mi
```

---

## 🟢 Infrastructure Issues

### Terraform Apply Fails

**Error:** `Error: error creating RDS DB Instance`

**Cause:** AWS resource conflict or invalid configuration

**Solution:**

```bash
# Validate Terraform configuration
cd infra/terraform/envs/dev
terraform validate

# Check what exists in AWS
aws rds describe-db-instances --region eu-central-1

# Refresh Terraform state
terraform refresh

# Try plan again
terraform plan

# Check for conflicts and resolve manually
terraform destroy  # Only if starting fresh
terraform apply
```

---

### RDS Connection from Kubernetes Fails

**Error:** `psql: could not translate host name "RDS_ENDPOINT" to address`

**Cause:** Pod can't resolve RDS endpoint or security groups block traffic

**Solution:**

```bash
# Test DNS resolution from pod
kubectl run -it debug --image=busybox --restart=Never -n eshop -- \
  nslookup <RDS_ENDPOINT>

# Test connectivity with nc (netcat)
kubectl run -it debug --image=busybox --restart=Never -n eshop -- \
  nc -zv <RDS_ENDPOINT> 5432

# Check security group allows 5432
aws ec2 describe-security-groups \
  --filter "Name=group-name,Values=eshop-rds-sg" \
  --region eu-central-1
```

---

## 🟣 CI/CD Issues

### GitHub Actions Workflow Fails

**Error:** Job fails with error message

**Solution:**

```bash
# Check workflow file syntax
cat .github/workflows/ci.yml | yamllint

# View workflow logs
gh run view RUN_ID --log

# Re-run workflow
gh run rerun RUN_ID

# Check runner logs
gh run view RUN_ID --log-failed
```

---

### Docker Build Fails in CI

**Error:** `docker build` command times out or fails

**Solution:**

```bash
# Check Dockerfile syntax
docker build --no-cache -t test .

# View build layers
docker history <IMAGE_ID>

# Manually run failing commands
docker run -it ubuntu:22.04 bash
# Run the commands from Dockerfile

# Optimize Dockerfile
# - Use smaller base images (alpine, slim)
# - Combine RUN commands to reduce layers
# - Order commands by frequency of change
```

---

## 📋 Diagnostic Checklist

### Before Asking for Help

- [ ] .NET SDK version: `dotnet --version`
- [ ] Docker version: `docker --version`
- [ ] Git commit: `git log -1 --oneline`
- [ ] OS information: `uname -a` (or `systeminfo` on Windows)
- [ ] Error message and full stack trace
- [ ] Steps to reproduce the issue
- [ ] What you've already tried

### Gathering Logs

```bash
# Docker Compose logs
docker-compose logs --tail=50 basket-api

# Aspire Dashboard logs
# Dashboard → Service → Console tab

# Kubernetes logs
kubectl logs deployment/basket-api -n eshop

# Application logs
tail -f logs/application.log

# System logs (macOS)
log stream --predicate 'process == "dotnet"'
```

---

## 🔧 Emergency Procedures

### Hard Reset Everything

```bash
# Stop all containers and services
docker-compose down -v
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Clean cache and build artifacts
dotnet clean
dotnet nuget locals all --clear
rm -rf bin obj .aspire

# Start fresh
cd codebase
dotnet run --project src/eShop.AppHost
```

### Kubernetes Emergency Cleanup

```bash
# Delete entire namespace (⚠️ all data lost)
kubectl delete namespace eshop

# Recreate
kubectl create namespace eshop
kubectl apply -f infra/k8s/eshop-services.yaml
```

### Infrastructure Emergency Reset

```bash
# ⚠️ WARNING: This deletes all AWS resources!
cd infra/terraform/envs/dev
terraform destroy

# Then recreate
terraform init
terraform apply
```

---

## 📞 Getting Help

### Internal Resources

- **Team Chat:** [Slack #eshop-dev]
- **Documentation:** [../docs/](../docs/)
- **Issues:** [GitHub Issues](https://github.com/dotnet-architecture/eShop/issues)

### External Resources

- **.NET Documentation:** https://learn.microsoft.com/en-us/dotnet/
- **ASP.NET Core:** https://learn.microsoft.com/en-us/aspnet/core/
- **Kubernetes:** https://kubernetes.io/docs/
- **Terraform:** https://www.terraform.io/docs/

---

**Last updated:** December 2025
