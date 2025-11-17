# 🏗️ eShop Terraform Infrastructure

Terraform Infrastructure as Code für eShop Microservices auf AWS.

## 📁 Repository Struktur

```
infra/terraform/
├── variables.tf          # Globale Variablen
├── modules/              # Wiederverwendbare Module
│   ├── vpc/             # VPC, Subnets, Gateways
│   ├── eks/             # EKS Cluster & Node Groups
│   ├── rds/             # PostgreSQL Database
│   ├── elasticache/     # Redis Cache
│   └── ecr/             # Container Registry
└── envs/                # Environment-spezifische Konfiguration
    ├── dev/             # Development Environment
    ├── staging/         # Staging Environment
    └── prod/            # Production Environment
```

## 🚀 Quick Start

### 1️⃣ Prerequisites
```bash
# AWS CLI konfigurieren
aws configure

# Terraform installieren (>= 1.6)
terraform --version

# Workspace wählen
cd infra/terraform/envs/dev
```

### 2️⃣ Development Environment
```bash
# Terraform initialisieren
terraform init

# Plan anzeigen
terraform plan

# Infrastructure erstellen
terraform apply
```

## 🌍 Environments

### 🟢 Development (`dev/`)
- **VPC CIDR:** `10.0.0.0/16`
- **EKS Nodes:** 2x `t3.medium` (1-5 scaling)
- **RDS:** `db.t3.micro` (20GB)
- **ElastiCache:** `cache.t3.micro` (1 node)

### 🟡 Staging (`staging/`)
- **VPC CIDR:** `10.1.0.0/16`  
- **EKS Nodes:** 3x `t3.medium/large` (2-8 scaling)
- **RDS:** `db.t3.small` (50GB, 14d backup)
- **ElastiCache:** `cache.t3.small` (2 nodes)

### 🔴 Production (`prod/`)
- **VPC CIDR:** `10.2.0.0/16`
- **EKS Nodes:** 6x `m5.large/xlarge` (3-15 scaling)
- **RDS:** `db.r6g.large` (200GB, Multi-AZ, 30d backup)
- **ElastiCache:** `cache.r6g.large` (3 nodes, encryption)

## 🔧 Module Usage

### VPC Module
Erstellt vollständige Netzwerk-Infrastruktur:
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  environment        = "dev"
  name_prefix       = "eshop-dev"
  vpc_cidr          = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}
```

### EKS Module  
Kubernetes-Cluster mit Auto-Scaling:
```hcl
module "eks" {
  source = "../../modules/eks"
  
  name_prefix        = "eshop-dev"
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version   = "1.28"
  desired_size      = 3
}
```

## 📦 Services & Repositories

ECR Repositories für alle eShop Services:
- `basket-api` - Warenkorb Service
- `catalog-api` - Produktkatalog Service  
- `identity-api` - Authentifizierung Service
- `ordering-api` - Bestellungen Service
- `order-processor` - Bestellungsverarbeitung
- `payment-processor` - Zahlungsabwicklung
- `webhooks-api` - Webhook Management
- `webapp` - Frontend Web Application
- `webhook-client` - Webhook Client

## 🔐 Security Features

### Development
- ✅ Grundlegende Verschlüsselung
- ✅ Private Subnets für Workloads
- ✅ NAT Gateways für Outbound

### Staging
- ✅ Enhanced Monitoring
- ✅ Multi-Node Redundancy
- ✅ Extended Backup Retention

### Production
- ✅ Multi-AZ Deployment
- ✅ Encryption at Rest & Transit
- ✅ Deletion Protection
- ✅ Performance Insights
- ✅ Advanced Monitoring

## 🏃‍♂️ CI/CD Integration

Integration mit GitHub Actions:
```yaml
# .github/workflows/terraform.yml
- name: Terraform Apply
  run: |
    cd infra/terraform/envs/${{ env.ENVIRONMENT }}
    terraform apply -auto-approve
```

## 🚧 Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| **VPC Module** | ✅ Complete | Full networking setup |
| **ECR Module** | ✅ Complete | Container registries |
| **EKS Module** | 🚧 TODO | Kubernetes cluster |
| **RDS Module** | 🚧 TODO | PostgreSQL database |
| **ElastiCache** | 🚧 TODO | Redis cache |
| **State Backend** | ⏳ Pending | S3 + DynamoDB |
| **OIDC Setup** | ⏳ Pending | GitHub Actions auth |

## 📋 Next Steps

### Week 3 - Infrastructure Implementation
1. **State Management:** S3 Backend + DynamoDB Lock
2. **EKS Implementation:** Vollständige Cluster-Konfiguration
3. **Database Setup:** RDS PostgreSQL mit Security Groups
4. **Cache Setup:** ElastiCache Redis mit Replication
5. **OIDC Integration:** GitHub Actions Authentication

### Week 4 - Deployment Integration
1. **Helm Charts:** Kubernetes Manifests
2. **Service Mesh:** Istio/Linkerd Integration  
3. **Monitoring:** Prometheus + Grafana + CloudWatch
4. **CI/CD Pipeline:** Vollständige Integration

## 🤝 Contributing

1. Neue Features in separaten Modules entwickeln
2. Environment-spezifische Anpassungen in `envs/` Ordnern
3. Terraform Code mit `terraform fmt` formatieren
4. Outputs für Cross-Module-Dependencies definieren

---
**🎯 Ziel:** Production-ready AWS Infrastructure für eShop Microservices