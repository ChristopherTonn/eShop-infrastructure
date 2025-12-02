# EKS Module

Amazon Elastic Kubernetes Service cluster configuration.

**Navigation:** [← VPC](VPC.md) | [Next: RDS →](RDS.md)

---

## 📋 Overview

The EKS module provisions a managed Kubernetes cluster on AWS with worker nodes, security groups, and IAM roles for role-based service account (IRSA) access.

**Location:** `infra/terraform/modules/eks/`

## 🏗️ Key Resources

- **EKS Control Plane**: AWS-managed Kubernetes API server (version 1.29+)
- **Node Group**: Auto Scaling Group with configurable instance types
- **Security Groups**: Control plane and worker node network access
- **IAM Roles**: IRSA for Kubernetes service accounts to access AWS services
- **OIDC Provider**: For GitHub Actions and other OIDC-compatible services
- **Add-ons**: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver

## 🔧 Configuration

### Input Variables

See `variables.tf` for:
- `cluster_name` - EKS cluster name
- `cluster_version` - Kubernetes version (e.g., "1.29")
- `vpc_id` - VPC for cluster
- `subnet_ids` - Private subnets for nodes
- `node_group_config` - desired, min, max capacity + instance types
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:
- `cluster_id` - Cluster identifier
- `cluster_endpoint` - Kubernetes API endpoint
- `cluster_arn` - ARN for IAM policies
- `oidc_provider_arn` - OIDC provider for GitHub Actions

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Kubernetes Deployment](../../deployment/KUBERNETES_DEPLOYMENT.md) - Deploying services to EKS
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/eks/`

**Last updated:** December 2025
