# Infrastructure Modules

Individual Terraform module documentation for eShop infrastructure components.

**Navigation:** [← Infrastructure Overview](../README.md) | [Up to Docs](../../INDEX.md)

---

## 📦 Available Modules

| Module | Purpose | AWS Service |
|--------|---------|-------------|
| [VPC](VPC.md) | Network infrastructure | EC2/VPC |
| [EKS](EKS.md) | Kubernetes cluster | EKS |
| [RDS](RDS.md) | PostgreSQL database | RDS |
| [ElastiCache](ELASTICACHE.md) | Redis cache | ElastiCache |
| [RabbitMQ](RabbitMQ.md) | Message broker | Kubernetes |
| [Logging](LOGGING.md) | Log aggregation | CloudWatch |
| [Monitoring](MONITORING.md) | Metrics & dashboards | Prometheus/Grafana |

---

## 🏗️ Module Structure

Each module follows standard Terraform conventions:

```
modules/MODULE_NAME/
├── main.tf           # Resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output values
└── README.md         # Module-specific documentation
```

---

## 🔧 Usage Example

```hcl
module "vpc" {
  source = "../modules/vpc"
  
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  
  tags = var.common_tags
}

module "eks" {
  source = "../modules/eks"
  
  cluster_name    = "eshop-eks"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  tags = var.common_tags
}
```

---

## 🔗 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Complete Infrastructure-as-Code guide
- [AWS Setup](../AWS_SETUP.md) - AWS account and IAM setup
- [Infrastructure Overview](../README.md) - High-level design

---

**Last updated:** December 2025
