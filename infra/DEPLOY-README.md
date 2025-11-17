# eShop AWS Infrastructure Deploy Script

## 🚀 Complete Infrastructure Deployment

### **One-Click Deployment**
```bash
cd infra
./deploy.sh
```

## ✅ What Gets Deployed

### **Core Infrastructure**
- **VPC** with public/private subnets across 2 AZs
- **Internet Gateway** + **NAT Gateways** for routing
- **Security Groups** with least-privilege access

### **Container Infrastructure**
- **EKS Cluster** (Kubernetes) with managed node groups
- **ECR Repositories** for container images
- **Application Load Balancer** for traffic distribution

### **Data Infrastructure** 
- **RDS PostgreSQL** database (encrypted)
- **ElastiCache Redis** for caching and sessions
- **S3 Buckets** for Terraform state storage

### **Monitoring & Security**
- **CloudWatch Logs** for centralized logging
- **VPC Flow Logs** for network monitoring
- **IAM Roles** with minimal required permissions

## 📋 Deployment Steps

The script automatically handles:

1. **🏗️ Terraform Infrastructure**
   - Validates configuration
   - Plans deployment
   - Applies changes with auto-approval

2. **🔐 EKS Cluster Access**
   - Updates kubeconfig for cluster access
   - Configures kubectl authentication

3. **🐳 ECR Container Registry**
   - Authenticates Docker with ECR
   - Prepares for image pushes

4. **🏗️ Application Image Build**
   - Builds Docker images for Linux/AMD64
   - Tags images for ECR repositories

5. **🚀 Kubernetes Deployment**
   - Creates dynamic deployment manifests
   - Deploys application with health checks
   - Exposes service via LoadBalancer

6. **🌐 Service Discovery**
   - Waits for LoadBalancer provisioning
   - Retrieves external access URL

## ⚡ Performance & Reliability

- **Deployment Time**: ~8-12 minutes
- **Auto-Recovery**: Built-in retry mechanisms
- **Health Checks**: Automatic readiness/liveness probes
- **Scaling**: Auto-scaling node groups (1-5 instances)

## 💰 Cost Optimization

### **Development Environment**
- **EKS Cluster**: $73/month (managed service)
- **t3.medium nodes**: ~$30/month (2 instances)
- **RDS t3.micro**: ~$15/month
- **ElastiCache t3.micro**: ~$13/month
- **NAT Gateway**: ~$32/month
- **Load Balancer**: ~$16/month

**Total**: ~$180/month for full development stack

### **Cost Savings Features**
- Spot instances for development (optional)
- Minimal instance sizes for dev workloads
- Auto-scaling to zero during off-hours

## 🔧 Prerequisites

- **AWS CLI** configured with proper credentials
- **kubectl** installed for Kubernetes management
- **Docker** running for image builds
- **Terraform** 1.5+ installed

## 🛡️ Security Features

- **Private Subnets** for application workloads
- **Encrypted Storage** for RDS and ElastiCache
- **Security Groups** with minimal required access
- **IAM Roles** following least-privilege principle
- **VPC Flow Logs** for network monitoring

## 📊 Monitoring & Observability

- **CloudWatch Logs** integration
- **Kubernetes Dashboard** access
- **Application Health Endpoints**
- **Infrastructure Metrics** collection

## 🚨 Common Issues & Solutions

### **EKS Access Issues**
```bash
# Re-configure cluster access
aws eks update-kubeconfig --region eu-central-1 --name <cluster-name>
```

### **ECR Login Problems**
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <registry-url>
```

### **LoadBalancer Not Ready**
```bash
# Check service status
kubectl get services
kubectl describe service eshop-webapp-service
```

## 📈 Next Steps After Deployment

1. **Verify Deployment**
   ```bash
   kubectl get pods
   kubectl get services
   ```

2. **Access Application**
   - Use provided LoadBalancer URL
   - Test health endpoints

3. **Monitor Resources**
   - Check CloudWatch dashboards
   - Monitor costs in AWS Console

4. **Scale if Needed**
   ```bash
   kubectl scale deployment eshop-webapp --replicas=3
   ```

---

**🎯 Result**: Production-ready eShop infrastructure deployed in under 15 minutes!