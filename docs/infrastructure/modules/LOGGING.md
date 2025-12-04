# Logging Module

CloudWatch and Fluent Bit log aggregation configuration.

**Navigation:** [← RabbitMQ](RabbitMQ.md) | [Next: Monitoring →](MONITORING.md)

---

## 📋 Overview

The Logging module configures centralized logging for eShop on AWS CloudWatch, with Fluent Bit as the log aggregator shipping container and application logs.

**Location:** `infra/terraform/modules/logging/`

## 🏗️ Key Resources

- **CloudWatch Log Groups**: EKS cluster, application, and service logs
- **Fluent Bit DaemonSet**: Log collection from all nodes
- **Log Retention Policies**: Automatic log cleanup based on retention days
- **IAM Role**: Service account permissions for CloudWatch access
- **ConfigMap**: Fluent Bit routing and filtering configuration
- **Log Streams**: Organized by application and service

## 🔧 Configuration

### Input Variables

See `variables.tf` for:

- `log_group_name` - CloudWatch log group name
- `retention_in_days` - Log retention period (e.g., 7, 30)
- `environment` - Environment name (dev, staging, prod)
- `cluster_name` - EKS cluster identifier
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:

- `log_group_name` - CloudWatch log group identifier
- `log_group_arn` - ARN for IAM policies
- `fluent_bit_namespace` - Kubernetes namespace

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Monitoring & Alerting](../../runbooks/MONITORING_ALERTS.md) - Log analysis and alerts
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/logging/`

**Last updated:** December 2025
