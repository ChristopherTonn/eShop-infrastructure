# ☸️ Kubernetes Deployment Guide

Deploy eShop to Amazon EKS with Helm, Terraform, and GitHub Actions.

**Navigation:** [← Back](../INDEX.md) | [Up ↑](../INDEX.md) | [Next: Troubleshooting →](TROUBLESHOOTING.md)

## 📋 Prerequisites

| Component | Details |
|-----------|---------|
| **AWS Account** | Access to eu-central-1 region |
| **IAM Permissions** | EKS, VPC, RDS, ElastiCache, ECR, IAM |
| **Tools** | `terraform`, `kubectl`, `aws-cli`, `helm`, `docker` |
| **Git** | Cloned eShop repository |

---

## 🏗️ Infrastructure Setup (Terraform)

### Step 1: Initialize Infrastructure

```bash
cd infra/terraform/envs/dev

# 1. Validate configuration
terraform init
terraform validate

# 2. Review what will be created
terraform plan -out=tfplan

# 3. Apply infrastructure
terraform apply tfplan
```

### Step 2: Create AWS Resources

The Terraform deployment creates:

```
VPC (10.0.0.0/16)
├── Public subnets (2 AZs)
├── Private subnets (2 AZs)
├── NAT Gateway
├── Internet Gateway
└── Route tables

EKS Cluster
├── Control plane (AWS managed)
├── Worker nodes (t3.medium, 2+ instances)
├── Security groups
├── IAM roles (IRSA)
├── OIDC provider
└── Add-ons (VPC CNI, CoreDNS, kube-proxy)

RDS PostgreSQL
├── Version: 15.4
├── Instance: db.t3.micro
├── Storage: 20GB
├── Multi-AZ: ✓ (automatic failover)
└── Backup: 7 days

ElastiCache Redis
├── Version: 7.0
├── Instance: cache.t3.micro
├── Nodes: 1
├── Automatic failover: ✓
└── Backup: enabled

ECR Repositories (one per service)
├── basket-api
├── catalog-api
├── identity-api
├── ordering-api
├── order-processor
├── payment-processor
├── webhooks-api
├── web
└── webhook-client
```

### Step 3: Configure kubectl

```bash
# Update kubeconfig to connect to EKS cluster
aws eks update-kubeconfig \
  --name eshop-eks \
  --region eu-central-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

---

## 📦 Container Registry (ECR)

### Build & Push Docker Images

```bash
cd codebase

# Set up ECR authentication
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.eu-central-1.amazonaws.com

# Build and push all services
./infra/build-and-push-images.sh

# Or manually for a specific service:
docker build -t basket-api src/Basket.API
docker tag basket-api:latest \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:latest
docker push \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:latest
```

---

## 🚀 Deploy to Kubernetes

### Step 1: Create Kubernetes Namespace

```bash
kubectl create namespace eshop
kubectl label namespace eshop app=eshop
```

### Step 2: Create Secrets

```bash
# Database credentials
kubectl create secret generic db-secret \
  --from-literal=username=eshop \
  --from-literal=password=$(openssl rand -base64 32) \
  -n eshop

# Redis credentials
kubectl create secret generic redis-secret \
  --from-literal=password=$(openssl rand -base64 32) \
  -n eshop

# RabbitMQ credentials
kubectl create secret generic rabbitmq-secret \
  --from-literal=username=guest \
  --from-literal=password=$(openssl rand -base64 32) \
  -n eshop
```

### Step 3: Deploy Services with Helm

```bash
cd infra/k8s

# Add Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Deploy using Helm charts
helm install eshop ./helm/eshop \
  --namespace eshop \
  --values values-dev.yaml \
  --set image.registry=123456789.dkr.ecr.eu-central-1.amazonaws.com

# Verify deployment
helm list -n eshop
kubectl get deployments -n eshop
kubectl get pods -n eshop
```

### Step 4: Verify Services Are Running

```bash
# Check pod status
kubectl get pods -n eshop -w

# View service endpoints
kubectl get svc -n eshop

# Check logs
kubectl logs -f deployment/basket-api -n eshop

# Port forward to test service
kubectl port-forward svc/basket-api 8001:80 -n eshop
# curl http://localhost:8001/health
```

---

## 🔄 Rolling Updates

### Update Service Version

```bash
# 1. Push new image to ECR
docker build -t basket-api:v2.0 src/Basket.API
docker tag basket-api:v2.0 \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:v2.0
docker push \
  123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:v2.0

# 2. Update Kubernetes deployment
kubectl set image deployment/basket-api \
  basket-api=123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:v2.0 \
  -n eshop

# 3. Monitor rollout
kubectl rollout status deployment/basket-api -n eshop

# 4. Verify new pods are running
kubectl get pods -n eshop -l app=basket-api
```

### Rollback if Issues Occur

```bash
# Check rollout history
kubectl rollout history deployment/basket-api -n eshop

# Rollback to previous version
kubectl rollout undo deployment/basket-api -n eshop

# Verify rollback
kubectl rollout status deployment/basket-api -n eshop
```

---

## 📊 Monitoring & Logs

### Access CloudWatch Logs

```bash
# View container logs in CloudWatch
aws logs tail /aws/eks/eshop-eks/cluster \
  --follow \
  --region eu-central-1

# View specific service logs
aws logs tail /aws/eks/eshop-eks/eshop/basket-api \
  --follow \
  --region eu-central-1
```

### Access Prometheus/Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring \
  svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Login: admin / PASSWORD
```

### View Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n eshop

# Describe pod for resource limits
kubectl describe pod POD_NAME -n eshop
```

---

## 🔐 Security Best Practices

### Network Security

```bash
# Enable network policies
kubectl apply -f infra/k8s/network-policies.yaml

# Verify ingress/egress rules
kubectl describe networkpolicy -n eshop
```

### Pod Security

```bash
# Apply pod security policy
kubectl apply -f infra/k8s/pod-security-policy.yaml

# Verify policies
kubectl describe psp eshop-restricted
```

### RBAC (Role-Based Access Control)

```bash
# Create service accounts for each service
kubectl create serviceaccount basket-api -n eshop
kubectl create serviceaccount catalog-api -n eshop

# Bind roles
kubectl apply -f infra/k8s/rbac.yaml

# Verify
kubectl get rolebinding -n eshop
```

---

## 📈 Scaling

### Manual Scaling

```bash
# Scale deployment to 3 replicas
kubectl scale deployment basket-api \
  --replicas=3 \
  -n eshop

# Verify
kubectl get pods -n eshop -l app=basket-api
```

### Horizontal Pod Autoscaling

```bash
# Create HPA (scales based on CPU)
kubectl autoscale deployment basket-api \
  --min=2 --max=10 \
  --cpu-percent=80 \
  -n eshop

# View HPA status
kubectl get hpa -n eshop -w
```

### Node Autoscaling

```bash
# EKS nodes automatically scale based on pod requests
# To check scaling group configuration:
aws autoscaling describe-auto-scaling-groups \
  --region eu-central-1
```

---

## 🧪 Testing Deployment

### Health Check

```bash
# Test service health endpoint
kubectl port-forward svc/basket-api 8001:80 -n eshop

curl http://localhost:8001/health
# Expected: HTTP 200 OK
```

### Integration Test

```bash
# Run E2E tests against deployed services
cd codebase/e2e
npx playwright test --config=playwright.config.prod.ts
```

---

## 🚨 Troubleshooting

### Pod Won't Start

```bash
# Check pod status
kubectl describe pod POD_NAME -n eshop

# Common issues:
# - ImagePullBackOff: ECR image not found or auth failed
# - Pending: Node resources exhausted or pod requirements too high
# - CrashLoopBackOff: Container exited, check logs
kubectl logs POD_NAME -n eshop
```

### Service Unreachable

```bash
# Check service exists
kubectl get svc -n eshop

# Check endpoints
kubectl get endpoints -n eshop

# Check network policies
kubectl describe networkpolicy -n eshop
```

### Database Connection Issues

```bash
# Test RDS connectivity from pod
kubectl run -it debug --image=busybox --restart=Never -n eshop -- \
  sh -c "nc -zv RDS_ENDPOINT 5432"

# Check RDS security group
aws ec2 describe-security-groups --region eu-central-1
```

---

## 📚 Related Documentation

- [Infrastructure Overview](../infrastructure/README.md)
- [Terraform Setup Guide](../infrastructure/TERRAFORM_GUIDE.md)
- [Environment Configuration](ENVIRONMENTS_AND_SECRETS.md)
- [CI/CD & Automation](../CI-CD.md)
- [Architecture](../ARCHITECTURE.md)

---

**Last updated:** December 2025
