# RDS Module

Amazon Relational Database Service (PostgreSQL) configuration.

**Navigation:** [← EKS](EKS.md) | [Next: ElastiCache →](ELASTICACHE.md)

---

## 📋 Overview

The RDS module creates a managed PostgreSQL database with multi-AZ deployment, automated backups, encryption, and high availability.

**Location:** `infra/terraform/modules/rds/`

## 🏗️ Key Resources

- **RDS Instance**: PostgreSQL 15.x engine
- **Multi-AZ Deployment**: Automatic failover to standby in different AZ
- **Automated Backups**: Daily snapshots with 7+ day retention
- **Encryption**: KMS encryption at rest and in transit
- **Security Group**: Restricted to EKS cluster access only
- **Monitoring**: CloudWatch metrics and logs
- **Parameter Groups**: Database configuration and optimization

## 🔧 Configuration

### Input Variables

See `variables.tf` for:

- `identifier` - Database instance name
- `engine_version` - PostgreSQL version (e.g., "15.4")
- `instance_class` - Instance type (e.g., db.t3.micro)
- `allocated_storage` - Storage size in GB
- `database_name` - Initial database name
- `username` / `password` - Database credentials
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:

- `endpoint` - RDS connection endpoint
- `port` - Database port (5432)
- `database_name` - Database identifier
- `security_group_id` - For additional ingress rules

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Backups Runbook](../../runbooks/BACKUPS.md) - Backup and restore procedures
- [Disaster Recovery](../../runbooks/DISASTER_RECOVERY.md) - Database failover
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/rds/`

**Last updated:** December 2025
