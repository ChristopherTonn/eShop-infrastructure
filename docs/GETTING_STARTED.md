# 🚀 Getting Started with eShop

Welcome to the eShop Reference Application! This guide will help you get up and running in 15 minutes.

**Navigation:** [← Architecture](ARCHITECTURE.md) | [Up ↑](INDEX.md) | [Developers: Aspire →](deployment/ASPIRE_QUICK_START.md)

## 📋 Prerequisites

Before you start, make sure you have:

- **Git:** `git --version` (should be 2.30+)
- **.NET 9:** `dotnet --version` (should be 9.0.x)
- **Docker Desktop:** Running and accessible
- **Visual Studio Code** or **Visual Studio 2022** (optional, but recommended)

**For Cloud Deployment (AWS):**
- AWS Account with appropriate permissions
- AWS CLI configured: `aws configure`
- Terraform 1.5+ installed

---

## 🎯 Choose Your Path

### 👨‍💻 **I Want to Develop Locally**

Perfect! Get the code running on your machine in minutes.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ChristopherTonn/eShop-infrastructure.git
   cd eShop-infrastructure
   ```

2. **Navigate to codebase:**
   ```bash
   cd codebase
   ```

3. **Restore dependencies:**
   ```bash
   dotnet restore eShop.Web.slnf
   ```

4. **Run via .NET Aspire:**
   ```bash
   dotnet run --project src/eShop.AppHost
   ```

5. **Open in browser:**
   - Aspire Dashboard: http://localhost:15213
   - eShop Web App: http://localhost:5173

✅ **Done!** Your local environment is ready.

**Next:** [Full Local Development Guide](deployment/LOCAL_DEVELOPMENT.md)

---

### 🏗️ **I Want to Deploy to AWS/Kubernetes**

Ready to deploy the infrastructure and application to the cloud.

1. **Review architecture:**
   - Read [System Architecture](ARCHITECTURE.md)
   - Understand the [Infrastructure Overview](infrastructure/README.md)

2. **Set up AWS:**
   ```bash
   cd infra
   ./deploy-infrastructure.sh
   ```
   See [AWS Setup Guide](infrastructure/AWS_SETUP.md) for details.

3. **Deploy application:**
   ```bash
   ./deploy-application.sh
   ```
   See [Kubernetes Deployment Guide](deployment/KUBERNETES_DEPLOYMENT.md).

4. **Verify deployment:**
   ```bash
   kubectl get deployments -n default
   kubectl logs -n default -l app=basket-api
   ```

✅ **Done!** Your application is running in Kubernetes.

**Next:** [Infrastructure Setup Guide](infrastructure/TERRAFORM_GUIDE.md) | [Deployment Troubleshooting](deployment/TROUBLESHOOTING.md)

---

### 📊 **I Want to Monitor & Operate the System**

Set up monitoring, logging, and alerting for production systems.

1. **Verify monitoring stack:**
   ```bash
   kubectl get pods -n monitoring
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   ```

2. **Access dashboards:**
   - Grafana: http://localhost:3000
   - Prometheus: http://localhost:9090

3. **Set up alerts:**
   - Configure [Monitoring & Alerting](runbooks/MONITORING_ALERTS.md)
   - Review [Scaling Guide](runbooks/SCALING.md)

**Next:** [Runbooks](runbooks/) | [Disaster Recovery](runbooks/DISASTER_RECOVERY.md)

---

## 🏗️ Project Structure

```
eShop/
├── codebase/              ← .NET Services, Frontend, Tests
│   ├── src/               ← Microservices (Basket, Catalog, Ordering, etc.)
│   ├── tests/             ← Unit & Functional tests
│   └── e2e/               ← End-to-End tests (Playwright)
│
├── infra/                 ← Infrastructure-as-Code (Terraform, Kubernetes)
│   ├── terraform/         ← AWS resources (VPC, EKS, RDS, etc.)
│   └── k8s/               ← Kubernetes manifests & Helm charts
│
├── .github/workflows/     ← CI/CD Pipelines (GitHub Actions)
│
└── docs/                  ← Documentation (you are here)
    ├── deployment/        ← Deployment guides
    ├── infrastructure/    ← Infrastructure guides
    └── runbooks/          ← Operational procedures
```

---

## 🚀 Common Tasks

### Build the solution
```bash
cd codebase
dotnet build eShop.Web.slnf
```

### Run tests
```bash
dotnet test
```

### Deploy to EKS
```bash
cd infra
terraform apply -target=module.eks
helm install eshop ./k8s/helm/eshop-app -f ./k8s/helm/values-dev.yaml
```

### Check logs
```bash
kubectl logs -f deployment/basket-api
```

### Scale a service
```bash
kubectl scale deployment basket-api --replicas=3
```

---

## 🆘 Troubleshooting

**Problem:** Build fails with "SDK version not found"
```bash
# Solution: Check global.json in codebase/
cat codebase/global.json
```

**Problem:** Kubernetes pod not starting
```bash
# Solution: Check pod logs and events
kubectl describe pod POD_NAME
kubectl logs POD_NAME
```

**Problem:** Can't connect to database
```bash
# Solution: Check RDS endpoint and security groups
aws rds describe-db-instances
```

📚 More help: [Troubleshooting Guide](deployment/TROUBLESHOOTING.md)

---

## 📚 Next Steps

Based on your role, explore the relevant documentation:

| Role | Start Here |
|------|-----------|
| Developer | [Local Development Setup](deployment/LOCAL_DEVELOPMENT.md) |
| DevOps Engineer | [Infrastructure Overview](infrastructure/README.md) |
| Site Reliability Engineer | [Runbooks](runbooks/) |

---

## 🔗 Useful Links

- [GitHub Repository](https://github.com/ChristopherTonn/eShop-infrastructure)
- [Azure eShop](https://github.com/dotnet/eShop)
- [.NET Aspire Docs](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)

---

**Questions?** Check the [Index](INDEX.md) or [Troubleshooting](deployment/TROUBLESHOOTING.md).

**Last updated:** December 2025
