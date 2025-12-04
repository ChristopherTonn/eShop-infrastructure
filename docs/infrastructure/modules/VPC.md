# VPC Module

Virtual Private Cloud configuration for eShop infrastructure.

**Navigation:** [← Infrastructure](../README.md) | [Next: EKS →](EKS.md)

---

## 📋 Overview

The VPC module creates a complete networking foundation for eShop on AWS, including subnets across multiple availability zones, NAT gateways, and route tables.

**Location:** `infra/terraform/modules/vpc/`

## 🏗️ Key Resources

- **VPC**: 10.0.0.0/16 CIDR block
- **Public Subnets**: 2 AZs (for NAT Gateway, ALB) - 10.0.1.0/24, 10.0.2.0/24
- **Private Subnets**: 2 AZs (for EKS nodes) - 10.0.10.0/24, 10.0.11.0/24
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Private subnet outbound access
- **Route Tables**: Separate for public and private traffic
- **Security Groups**: Network access control

## 🔧 Configuration

### Input Variables

See `variables.tf` in module for:

- `vpc_cidr` - VPC CIDR block
- `public_subnet_cidrs` - Public subnet ranges
- `private_subnet_cidrs` - Private subnet ranges
- `availability_zones` - AZs to use
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:

- `vpc_id` - VPC identifier
- `public_subnet_ids` - Public subnet IDs
- `private_subnet_ids` - Private subnet IDs
- `nat_gateway_ips` - NAT Gateway IPs for whitelisting

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [AWS Setup](../AWS_SETUP.md) - AWS account configuration
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/vpc/`

**Last updated:** December 2025
