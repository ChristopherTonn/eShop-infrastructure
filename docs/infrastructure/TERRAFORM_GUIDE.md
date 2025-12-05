# 🏗️ Terraform Infrastructure-as-Code Guide

Deploy and manage eShop AWS infrastructure using Terraform.

**Navigation:** [← Back](../INDEX.md) | [Up ↑](../INDEX.md) | [Next: AWS Setup →](AWS_SETUP.md)

## 📋 Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| **Terraform** | >= 1.5.0 | `terraform --version` |
| **AWS CLI** | >= 2.0 | `aws --version` |
| **kubectl** | >= 1.28 | `kubectl version --client` |
| **Git** | >= 2.0 | `git --version` |

---

## 📁 Directory Structure

```
infra/terraform/
├── bootstrap/                    ← Initial AWS setup
│   ├── main.tf                   ← Create S3 bucket, DynamoDB for state
│   └── variables.tf
├── envs/                         ← Environment-specific configs
│   ├── dev/
│   │   ├── main.tf               ← Module instantiation
│   │   ├── variables.tf          ← Variable definitions
│   │   ├── terraform.tfvars      ← Environment values
│   │   └── outputs.tf            ← Export values
│   ├── staging/
│   └── prod/
├── modules/                      ← Reusable infrastructure modules
│   ├── vpc/                      ← Virtual Private Cloud
│   ├── eks/                      ← Kubernetes cluster
│   ├── rds/                      ← Database
│   ├── elasticache/              ← Redis cache
│   ├── ecr/                      ← Container registry
│   ├── iam/                      ← Identity & Access Management
│   ├── rabbitmq/                 ← Message broker
│   ├── logging/                  ← CloudWatch logs
│   └── monitoring/               ← Prometheus & Grafana
├── README.md                     ← Main documentation
└── variables.tf                  ← Global variables
```

---

## 🚀 Quick Start

### Step 1: Bootstrap AWS Account

```bash
cd infra/terraform/bootstrap

# Review what will be created
terraform init
terraform plan

# Create S3 bucket and DynamoDB table for state
terraform apply
```

### Step 2: Deploy Development Environment

```bash
cd infra/terraform/envs/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review infrastructure changes
terraform plan -out=tfplan

# Create infrastructure
terraform apply tfplan
```

### Step 3: Verify Deployment

```bash
# Check AWS resources created
aws ec2 describe-vpcs --region eu-central-1
aws eks describe-cluster --name eshop-eks --region eu-central-1
aws rds describe-db-instances --region eu-central-1

# Configure kubectl
aws eks update-kubeconfig \
  --name eshop-eks \
  --region eu-central-1

# Verify Kubernetes cluster
kubectl cluster-info
kubectl get nodes
```

---

## 🔧 Configuration

### Environment Variables

Create `.tfvars` file for each environment:

```hcl
# infra/terraform/envs/dev/terraform.tfvars

aws_region             = "eu-central-1"
project_name           = "eshop"
environment            = "dev"

# EKS Configuration
eks_version            = "1.29"
eks_instance_types     = ["t3.medium"]
eks_desired_capacity   = 2
eks_min_capacity       = 1
eks_max_capacity       = 4

# RDS Configuration
rds_allocated_storage  = 20
rds_instance_class     = "db.t3.micro"
rds_engine_version     = "15.4"

# ElastiCache Configuration
elasticache_node_type  = "cache.t3.micro"
elasticache_num_nodes  = 1

# Tagging
common_tags = {
  Project     = "eShop"
  Environment = "dev"
  ManagedBy   = "Terraform"
}
```

---

## 🔐 State Management

### Store State in S3

```hcl
# infra/terraform/envs/dev/main.tf

terraform {
  backend "s3" {
    bucket         = "eshop-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-terraform-locks"
    encrypt        = true
  }
}
```

### State File Operations

```bash
# List resources in state
terraform state list

# Show resource details
terraform state show aws_eks_cluster.eshop

# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Refresh state from AWS
terraform refresh
```

---

## 📦 Modules

### VPC Module

Creates a Virtual Private Cloud with:
- 2 public subnets (for NAT Gateway, ALB)
- 2 private subnets (for EKS nodes)
- Internet Gateway
- NAT Gateway
- Route tables

**Usage:**
```hcl
module "vpc" {
  source = "../modules/vpc"
  
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  
  tags = var.common_tags
}
```

---

### EKS Module

Creates a Kubernetes cluster with:
- Control plane (AWS managed)
- Worker node group
- Security groups
- IAM roles (IRSA)
- Add-ons (VPC CNI, CoreDNS, kube-proxy)

**Usage:**
```hcl
module "eks" {
  source = "../modules/eks"
  
  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_version
  vpc_id          = module.vpc.id
  subnet_ids      = module.vpc.private_subnet_ids
  
  node_group_config = {
    desired_capacity = var.eks_desired_capacity
    min_capacity     = var.eks_min_capacity
    max_capacity     = var.eks_max_capacity
    instance_types   = var.eks_instance_types
  }
  
  tags = var.common_tags
}
```

---

### RDS Module

Creates a PostgreSQL database with:
- Multi-AZ deployment (automatic failover)
- Automated backups (7-day retention)
- KMS encryption
- Security group rules

**Usage:**
```hcl
module "rds" {
  source = "../modules/rds"
  
  identifier       = "${var.project_name}-postgres"
  engine_version   = var.rds_engine_version
  instance_class   = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  vpc_id           = module.vpc.id
  subnet_ids       = module.vpc.private_subnet_ids
  
  database_name = "eshop"
  username      = "eshop"
  password      = random_password.db_password.result
  
  tags = var.common_tags
}
```

---

### ElastiCache Module

Creates a Redis cluster with:
- Single or multi-node configuration
- Automatic failover
- Automated backups
- Parameter groups for optimization

**Usage:**
```hcl
module "elasticache" {
  source = "../modules/elasticache"
  
  cluster_id        = "${var.project_name}-redis"
  engine            = "redis"
  engine_version    = "7.0"
  node_type         = var.elasticache_node_type
  num_cache_nodes   = var.elasticache_num_nodes
  vpc_id            = module.vpc.id
  subnet_ids        = module.vpc.private_subnet_ids
  
  auth_token = random_password.redis_password.result
  
  tags = var.common_tags
}
```

---

## 🔄 Common Tasks

### Update Environment

```bash
cd infra/terraform/envs/dev

# Modify terraform.tfvars
# e.g., change instance type or capacity

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Scale EKS Cluster

```bash
# Increase node capacity
terraform apply \
  -var="eks_desired_capacity=4" \
  -var="eks_max_capacity=8"

# Or update terraform.tfvars:
# eks_desired_capacity = 4
# eks_max_capacity     = 8
```

### Rotate Database Password

```bash
# Generate new password
aws secretsmanager create-secret \
  --name eshop/rds/password \
  --secret-string "$(openssl rand -base64 32)"

# Update Terraform
terraform apply \
  -var="rds_password=$(aws secretsmanager get-secret-value --secret-id eshop/rds/password --query SecretString)"
```

### Upgrade Kubernetes Version

```bash
# Update EKS version in terraform.tfvars
eks_version = "1.30"

# Plan upgrade
terraform plan

# Apply upgrade (~15-20 minutes)
terraform apply
```

---

## 🔍 Troubleshooting

### Terraform Plan Shows Unexpected Changes

```bash
# Refresh state from AWS
terraform refresh

# Check for manual changes in AWS Console
# Update Terraform to match actual state

# Or import changes:
terraform import aws_instance.example <instance-id>
```

### Resource Deletion Hangs

```bash
# Check AWS resources manually
aws ec2 describe-instances --region eu-central-1

# Check for resource dependencies
# (e.g., security groups attached to ENIs)

# Force delete (⚠️ use with caution)
terraform destroy -target=module.vpc
```

---

## 📚 Related Documentation

- [Infrastructure Overview](README.md)
- [AWS Setup Guide](AWS_SETUP.md)
- [Module Documentation](modules/)
- [Deployment Guide](../deployment/KUBERNETES_DEPLOYMENT.md)

---

**Last updated:** December 2025
