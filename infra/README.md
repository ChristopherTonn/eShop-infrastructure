# 🏗️ eShop Infrastructure – DevOps & Cloud Architecture Project

This directory contains the **Infrastructure-as-Code (IaC)** and deployment automation for the **Microsoft eShop** microservices application — part of the *DevOps & Cloud Architecture* training project.

The infrastructure implements a **cloud-native multi-environment deployment** on **AWS**, managed via Terraform, Helm, and **automated shell scripts** under the "Everything as Code" paradigm.

---

## 🚀 Quick Start - Shell Script Strategy

### **🎯 One-Click Operations**

```bash
cd infra

# Deploy complete infrastructure + application
./deploy.sh

# Destroy everything (100% cost savings)  
./destroy.sh
```

**Why Shell Scripts?** Our battle-tested approach prioritizes **speed**, **reliability**, and **simplicity** over complex CI/CD pipelines for infrastructure management.

| Shell Scripts | Traditional CI/CD |
|--------------|-------------------|
| ⚡ **2-3 min execution** | ⏳ 10+ min pipeline overhead |
| 🔍 **Real-time debugging** | 🌫️ YAML log hunting |
| 🎯 **Direct AWS API calls** | 🎲 Pipeline dependencies |
| 💰 **$0 tooling cost** | 💸 CI/CD infrastructure |

### **📚 Complete Documentation**
- **[🚀 Deployment Guide](DEPLOY-README.md)** - One-click infrastructure deployment
- **[💥 Destruction Guide](DESTROY-README.md)** - Complete cleanup & cost elimination

---

## 🌐 Overview

The goal of this infrastructure is to provide a **scalable, secure, and maintainable AWS environment** for the eShop microservices application.

It supports three environments:
- **Development**
- **Staging**
- **Production**

### Core Technologies

| Purpose | Tool / Service |
|----------|----------------|
| Infrastructure as Code | Terraform |
| Container Orchestration | Amazon EKS (Kubernetes) |
| Configuration as Code | Ansible (optional) |
| CI/CD Automation | GitHub Actions with OIDC → AWS IAM |
| Monitoring | Prometheus + Grafana + CloudWatch |
| Secrets Management | AWS Secrets Manager (CSI driver for EKS) |
| Messaging | RabbitMQ (Helm chart) |
| Caching | Redis (ElastiCache) |
| Database | PostgreSQL (Amazon RDS) |
| Networking | VPC, ALB, Route 53 |

---

## 🧱 Directory Structure

```bash
infra/
├── terraform/                # Infrastructure as Code
│   ├── modules/              # Reusable Terraform modules  
│   │   ├── vpc/              # VPC with multi-AZ setup
│   │   ├── eks/              # EKS cluster configuration
│   │   ├── rds/              # PostgreSQL database
│   │   ├── elasticache/      # Redis cluster
│   │   ├── ecr/              # Container repositories
│   │   └── iam-github-oidc/  # OIDC trust for GitHub Actions
│   └── envs/                 # Environment-specific configs
│       ├── dev/              # Development environment
│       ├── staging/          # Staging environment  
│       └── prod/             # Production environment
├── deploy.sh                 # 🚀 One-click deployment automation
├── destroy.sh                # 💥 Complete infrastructure destroyer
├── DEPLOY-README.md          # 📚 Deployment documentation
├── DESTROY-README.md         # 📚 Destruction & cleanup guide
├── k8s/                      # Kubernetes configurations
│   ├── helm/                 # Helm charts
│   │   ├── eshop-app/        # Umbrella chart for microservices
│   │   └── dependencies/     # Third-party charts (RabbitMQ, Redis)
│   └── manifests/            # Cluster-level configs
├── ansible/                  # Optional config automation
└── README.md                 # This file
```

---

## ⚙️ Deployment Flow

### **🚀 Automated Shell Script Approach (Recommended)**

Our optimized deployment uses battle-tested shell scripts for maximum reliability:

```bash
# Complete infrastructure + application deployment
cd infra
./deploy.sh
```

**What happens automatically:**
1. **Terraform validation & planning** 
2. **AWS infrastructure provisioning** (VPC, EKS, RDS, ElastiCache)
3. **EKS cluster access configuration**
4. **ECR authentication & Docker login**
5. **Application image building & pushing**
6. **Kubernetes deployment with health checks**
7. **LoadBalancer service exposure**

**Result:** Production-ready eShop in **~12 minutes**

### **🔧 Manual Terraform Approach (Advanced)**

For learning or custom configurations:

```bash
cd infra/terraform/envs/dev
terraform init
terraform plan -var="project=eshop" -var="region=eu-central-1"
terraform apply -auto-approve

# Then manually configure EKS and deploy application
make kube-login ENV=dev
make helm-deploy ENV=dev
```

---

### 3. CI/CD Integration (GitHub Actions)

- **CI workflow (`ci.yml`)** → restores, builds, tests and scans .NET services.  
- **CD workflow (`cd.yml`)** → assumes AWS role via OIDC, builds & pushes images to ECR, then deploys via Helm to the correct environment.

The pipeline stages:
1. Code pushed → build & test (.NET)
2. Trivy scan for vulnerabilities
3. Push image to ECR
4. Helm deploy → EKS (dev → stage → prod)

---

## 🔒 Security

- AWS IAM roles follow **least privilege** principles  
- GitHub → AWS via **OIDC** (no long-lived credentials)  
- Kubernetes RBAC per namespace  
- Secrets stored in **AWS Secrets Manager** (mounted via CSI driver)  
- Enforced **TLS / HTTPS** for all ingress traffic  

---

## 📊 Observability & Logging

- **Prometheus** for metrics collection  
- **Grafana** for dashboards (golden signals)  
- **Alertmanager** for notifications (Slack/Email)  
- **CloudWatch** for centralized AWS logs  

Dashboards and alert rules are stored in the `k8s/helm/monitoring` subchart (Week 5 deliverable).  

---

## 🧩 Maintenance & Recovery

- Automated **RDS snapshots** + S3 backups  
- Documented **restore procedures** in `/docs/runbooks/`  
- Backup verification scheduled weekly via GitHub Actions  

---

## ✅ Quickstart Summary

| Operation | Command | Time | Description |
|-----------|---------|------|-------------|
| **🚀 Deploy** | `./deploy.sh` | ~12 min | Complete infrastructure + application |
| **💥 Destroy** | `./destroy.sh` | ~3 min | Total cleanup (100% cost savings) |
| **🔍 Manual Terraform** | `terraform apply` | ~8 min | Infrastructure only |
| **📊 Status Check** | `kubectl get all` | instant | Verify deployment health |

### **💰 Cost Management**
- **Active Development**: ~$180/month  
- **Destroyed Infrastructure**: **$0/month** (complete cleanup)
- **Quick Tip**: Use `./destroy.sh` when not actively developing

### **🛡️ Emergency Recovery**
```bash
# Complete infrastructure reset
./destroy.sh && sleep 30 && ./deploy.sh
```

---

## 📚 Additional Resources
- Architecture Diagrams → [`/docs/architecture/`](../docs/architecture/)
- Runbooks & DR Procedures → [`/docs/runbooks/`](../docs/runbooks/)
- CI/CD Workflows → [`.github/workflows/`](../../.github/workflows/)

---

**Author:** DevOps & Cloud Architecture Project Team  
**Last Updated:** October 2025  