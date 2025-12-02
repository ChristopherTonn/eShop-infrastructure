# 📚 eShop Documentation Index

Welcome to the eShop Reference Application documentation. This guide helps you navigate documentation based on your role.

---

## 👨‍💻 **For Developers**

Building and running eShop locally for development.

| Guide | Purpose |
|-------|---------|
| [Getting Started](GETTING_STARTED.md) | First steps - setup your environment |
| [Local Development Setup](deployment/LOCAL_DEVELOPMENT.md) | Development environment configuration |
| [ASPIRE Quick Start](deployment/ASPIRE_QUICK_START.md) | Running services via .NET Aspire |
| [Troubleshooting](deployment/TROUBLESHOOTING.md) | Common issues and solutions |

---

## 🏗️ **For DevOps & Infrastructure Engineers**

Building and maintaining cloud infrastructure.

| Guide | Purpose |
|-------|---------|
| [Infrastructure Overview](infrastructure/README.md) | High-level infrastructure design |
| [AWS Setup & Configuration](infrastructure/AWS_SETUP.md) | AWS account and IAM setup |
| [Terraform Setup Guide](infrastructure/TERRAFORM_GUIDE.md) | Infrastructure-as-Code with Terraform |
| [Kubernetes Deployment](deployment/KUBERNETES_DEPLOYMENT.md) | Deploying to EKS |
| [Environment & Secrets](deployment/ENVIRONMENTS_AND_SECRETS.md) | Managing secrets and configurations |

### Module Documentation

- [Modules Overview](infrastructure/modules/) - Individual Terraform module guide
- [VPC Module](infrastructure/modules/VPC.md) - Virtual Private Cloud setup
- [EKS Module](infrastructure/modules/EKS.md) - Kubernetes cluster configuration
- [RDS Module](infrastructure/modules/RDS.md) - PostgreSQL database
- [ElastiCache Module](infrastructure/modules/ELASTICACHE.md) - Redis caching
- [RabbitMQ Module](infrastructure/modules/RabbitMQ.md) - Message broker
- [Logging Module](infrastructure/modules/LOGGING.md) - CloudWatch integration
- [Monitoring Module](infrastructure/modules/MONITORING.md) - Prometheus & Grafana

---

## 🚨 **For Site Reliability Engineers (SREs)**

Operating, monitoring, and maintaining production systems.

| Guide | Purpose |
|-------|---------|
| [Runbooks Index](runbooks/) | Operational procedures |
| [Disaster Recovery](runbooks/DISASTER_RECOVERY.md) | Backup and recovery procedures |
| [Monitoring & Alerting](runbooks/MONITORING_ALERTS.md) | Health checks and alerting setup |
| [Scaling Guide](runbooks/SCALING.md) | Horizontal & vertical scaling |
| [Backups & Retention](runbooks/BACKUPS.md) | Data backup strategies |

---

## 🏛️ **Architecture & Design**

Understanding how eShop is designed.

| Document | Content |
|----------|---------|
| [System Architecture](ARCHITECTURE.md) | Components, data flows, design decisions |
| 📄 [Technical Objectives](pdf/Technical%20Objective%20Paper.pdf) | Project goals and success criteria (PDF) |
| 📄 [Architecture Diagrams](pdf/System%20Architecture%20Diagram.pdf) | Visual system design (PDF) |

---

## 🔄 **CI/CD & DevOps**

Automated testing, building, and deployment.

| Guide | Purpose |
|-------|---------|
| [CI/CD & Automation](CI-CD.md) | Pipelines, workflows, deployment |
| [GitHub Workflows](../.github/workflows/README.md) | Detailed workflow documentation |

---

## 📋 **Quick Links**

- **Main README:** [Project Overview](../README.md)
- **Code of Conduct:** [Community Guidelines](CODE-OF-CONDUCT.md)
- **PDF Downloads:** [Technical Documents](pdf/)

---

## 📖 **Documentation Structure**

```
docs/
├── INDEX.md                           ← You are here
├── GETTING_STARTED.md                 ← Start here
├── ARCHITECTURE.md                    ← Design overview
├── deployment/                        ← Deployment guides
├── infrastructure/                    ← Infrastructure setup
│   └── modules/                       ← Individual Terraform modules
├── runbooks/                          ← Operational procedures
└── pdf/                               ← Reference documents
```

---

## 🆘 **Getting Help**

- **Found a bug?** Create an issue on GitHub
- **Have a question?** Check [Troubleshooting](deployment/TROUBLESHOOTING.md)
- **Want to contribute?** See [Contributing](CONTRIBUTING.md)

---

**Last updated:** December 2025  
**Version:** 1.0
