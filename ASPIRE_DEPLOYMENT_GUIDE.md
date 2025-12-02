# 🚀 eShop Aspire Deployment Guide

## Overview

This guide explains how to deploy eShop infrastructure on AWS and integrate it with **Aspire** (.NET Orchestration Tool).

**Aspire** handles:

- Service orchestration (.NET services)
- Local development (dashboard, debugging)
- Container builds (publishes to ECR automatically)
- Environment configuration

**Terraform** handles:

- AWS infrastructure (EKS, RDS, ElastiCache, ECR)
- Network setup (VPC, subnets, security groups)
- Identity & access (IAM roles, OIDC)

---

## 1️⃣ Infrastructure Deployment

### Prerequisites

```bash
# 1. AWS Credentials
aws configure

# 2. Required Tools
✓ terraform (>= 1.5)
✓ kubectl (>= 1.28)
✓ aws-cli (>= 2.0)
✓ dotnet SDK (>= 8.0) - for Aspire
✓ docker (>= 20.0) - for container builds

# 3. SSH Key
# Script creates this automatically, but ensure it's available:
ls -la ~/.ssh/eshop-dev-key.pem
```

### Deploy

```bash
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra

# Run the deployment script
bash deploy-fixed.sh

# The script will:
# ✅ Initialize Terraform
# ✅ Validate configuration
# ✅ Create AWS infrastructure
# ✅ Configure kubectl
# ✅ Setup ECR authentication
# ✅ Create .aspirerc environment file
```

### What Gets Created

| Resource        | Details                          |
| --------------- | -------------------------------- |
| **VPC**         | 10.0.0.0/16 with 2 AZs           |
| **EKS**         | Kubernetes 1.28 cluster          |
| **RDS**         | PostgreSQL 15.10 (db.t3.micro)   |
| **ElastiCache** | Redis 7.0 (cache.t3.micro)       |
| **ECR**         | 9 repositories for microservices |
| **IAM**         | OIDC provider, IRSA roles        |
| **Security**    | KMS encryption, security groups  |

### Estimated Cost

```
EKS (1 t3.medium):        ~$0.033/h
RDS (db.t3.micro):        ~$0.005/h
ElastiCache (t3.micro):   ~$0.007/h
NAT Gateway + ALB:        ~$0.020/h
────────────────────────────────
TOTAL:                    ~$0.065/h (~$48/month)
```

---

## 🔄 Kubernetes Version Update (1.28 → 1.29)

**Status:** Support for K8s 1.28 ends 2025-11-26. Update to 1.29 is recommended.

### Update Process (30 minutes)

```bash
# 1. Backup current state
cd infra/terraform/envs/dev
cp terraform.tfstate terraform.tfstate.backup.1.28

# 2. Plan the upgrade
terraform plan -out=k8s-upgrade.tfplan

# 3. Review changes (should only show eks_cluster_version update)
terraform show k8s-upgrade.tfplan

# 4. Apply upgrade (~15-20 minutes)
terraform apply k8s-upgrade.tfplan

# 5. Verify upgrade
kubectl get nodes -o wide
# All nodes should show v1.29.x

# 6. Validate cluster health
kubectl get pods --all-namespaces
kubectl get svc
```

### What Happens During Update

```
Timeline:
├─ Control Plane upgrade: ~5-10 minutes (no service disruption)
├─ Node group upgrade: ~5-10 minutes per node (rolling update)
├─ Services: Continue running (traffic redirected during node updates)
└─ Total: ~15-20 minutes
```

### Rollback (if needed)

```bash
# Revert to 1.28 if issues arise
terraform plan -out=k8s-rollback.tfplan  # Automatically uses .tfstate.backup
terraform apply k8s-rollback.tfplan
```

---

## 2️⃣ Aspire Integration

### Step 1: Load Environment Variables

```bash
cd /Users/christophertonn/Documents/WORKSPACE/eShop

# Load all AWS credentials and service URLs
source .aspirerc

# Verify environment
echo "ECR Registry: $ASPIRE_CONTAINER_REGISTRY"
echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo "RDS Host: $RDS_HOST"
echo "Redis Host: $REDIS_HOST"
```

### Step 2: Start Aspire

```bash
cd src/eShop.AppHost

# Run with debug mode (shows logs in terminal)
dotnet run

# Or run in background
dotnet run > aspire.log 2>&1 &
```

### What Aspire Does

```
1. Discovers Services
   - Reads eShop.AppHost configuration
   - Finds all microservices (APIs, processors)

2. Builds Containers
   - Compiles each .NET service
   - Creates Docker images
   - Pushes to ECR automatically

3. Deploys to Kubernetes
   - Creates Kubernetes deployments
   - Sets up services (LoadBalancer/ClusterIP)
   - Configures health checks

4. Provides Dashboard
   - Real-time service monitoring
   - Logs aggregation
   - Endpoint access

5. Manages Dependencies
   - Injects RDS connection strings
   - Configures Redis for caching
   - Sets up inter-service communication
```

---

## 3️⃣ Accessing Services

### Aspire Dashboard

```bash
# Available immediately when running "dotnet run"
http://localhost:18888

# Shows:
- All running services
- Resource usage
- Logs for each service
- Endpoints and URLs
```

### Individual Services

Once Aspire deploys services, access them via:

```
Identity API:     http://localhost:5001/swagger
Catalog API:      http://localhost:5010/swagger
Basket API:       http://localhost:5011/swagger
Ordering API:     http://localhost:5012/swagger
WebApp:           http://localhost:8080
```

### View Logs

```bash
# Aspire shows logs in dashboard, or via kubectl:

# Watch all pods
kubectl get pods --watch

# View service logs
kubectl logs deployment/identity-api -f
kubectl logs deployment/catalog-api -f
kubectl logs deployment/basket-api -f

# Describe a pod (for troubleshooting)
kubectl describe pod <pod-name>
```

---

## 4️⃣ Kubernetes Management

### View Cluster Status

```bash
# Check nodes
kubectl get nodes -o wide

# Check pods in default namespace
kubectl get pods

# Check all namespaces
kubectl get pods --all-namespaces

# Get service endpoints
kubectl get svc

# Get ingress (if configured)
kubectl get ingress
```

### Scale Services

```bash
# Scale catalog-api to 3 replicas
kubectl scale deployment/catalog-api --replicas=3

# Check deployment status
kubectl get deployment
```

### Forward Ports (local access)

```bash
# Forward EKS service to local port
kubectl port-forward svc/catalog-api 5010:80

# Now accessible at http://localhost:5010
```

---

## 5️⃣ Troubleshooting

### Service Won't Start

```bash
# Check pod events
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name> --previous  # if crashed

# Check environment variables
kubectl exec <pod-name> -- env | grep RDS
```

### Database Connection Issues

```bash
# Verify RDS is accessible
aws rds describe-db-instances --region eu-central-1

# Check security group allows EKS nodes
aws ec2 describe-security-groups --query 'SecurityGroups[?Tags[?Key==`Name`&&Value==`*rds*`]]'

# Manually test RDS connection from EKS pod
kubectl run -it --image=postgres:15 --restart=Never psql -- \
  -h $RDS_HOST -U $RDS_USERNAME -d $RDS_DATABASE
```

### ECR Push Failures

```bash
# Verify ECR login
docker login $ASPIRE_CONTAINER_REGISTRY

# Check ECR repository exists
aws ecr describe-repositories --region eu-central-1

# View ECR image tags
aws ecr describe-images \
  --repository-name basket-api \
  --region eu-central-1
```

### kubectl Not Connected

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig \
  --name eshop-dev-cluster \
  --region eu-central-1

# Test cluster access
kubectl cluster-info
```

---

## 6️⃣ Development Workflow

### Local Iteration

```bash
# 1. Edit service code locally (e.g., Catalog.API)
vim src/Catalog.API/Program.cs

# 2. Rebuild via Aspire dashboard
# - Click "Rebuild" on service card
# - Or restart the service

# 3. New container is built & pushed to ECR
# 4. EKS pulls new image and updates pod

# 5. Access updated service
curl http://localhost:5010/swagger
```

### Debugging in Aspire

```bash
# 1. Set breakpoint in VS Code
# 2. Open Aspire dashboard
# 3. Click service → "Debug in VS Code"
# 4. VS Code attaches debugger
# 5. Debug as normal (breakpoints work, inspect variables)
```

### View Container Images in ECR

```bash
# List all images
aws ecr describe-images --repository-name basket-api --region eu-central-1

# View image details
aws ecr describe-images \
  --repository-name catalog-api \
  --region eu-central-1 \
  --query 'imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]'
```

---

## 7️⃣ Cleanup

### Stop Aspire

```bash
# If running in foreground
Ctrl+C

# If running in background
pkill -f "dotnet run"
```

### Delete AWS Infrastructure (IMPORTANT!)

```bash
# Navigate to Terraform directory
cd infra/terraform/envs/dev

# Delete all resources
terraform destroy

# Confirm when prompted
# This will:
# ✓ Delete EKS cluster
# ✓ Delete RDS database
# ✓ Delete ElastiCache
# ✓ Delete VPC and subnets
# ✓ Delete ECR repositories
# ✓ Stop billing immediately
```

### Clean Local Files

```bash
# Remove Aspire environment file (recreated on next deploy)
rm ~/.aspirerc

# Remove kubeconfig context (optional)
kubectl config delete-context eshop-dev
```

---

## 📚 Additional Resources

- [Aspire Documentation](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## ⚡ Quick Reference

```bash
# Deploy infrastructure
bash infra/deploy-fixed.sh

# Start Aspire
cd src/eShop.AppHost && source ../../.aspirerc && dotnet run

# View dashboard
http://localhost:18888

# Watch pods
kubectl get pods --watch

# View logs
kubectl logs -f deployment/basket-api

# Scale service
kubectl scale deployment/catalog-api --replicas=3

# Port forward
kubectl port-forward svc/basket-api 5011:80

# Destroy infrastructure
cd infra/terraform/envs/dev && terraform destroy -auto-approve
```

---

**Last Updated:** 2025-11-26  
**Status:** ✅ Production Ready  
**Cost:** ~$48/month
