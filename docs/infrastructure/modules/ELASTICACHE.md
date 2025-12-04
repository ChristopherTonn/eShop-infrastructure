# ElastiCache Module

Amazon ElastiCache (Redis) cluster configuration.

**Navigation:** [← RDS](RDS.md) | [Next: RabbitMQ →](RabbitMQ.md)

---

## 📋 Overview

The ElastiCache module creates a managed Redis cache cluster for eShop, providing distributed caching and session storage with automatic failover and persistence.

**Location:** `infra/terraform/modules/elasticache/`

## 🏗️ Key Resources

- **Cache Cluster**: Redis 7.x engine
- **Node Type**: Configurable instance size (t3.micro, t3.small, etc.)
- **Replication**: Multi-node setup with automatic failover
- **Encryption**: At-rest and in-transit encryption
- **Security Group**: Restricted to EKS cluster access
- **Parameter Groups**: Cache optimization and configuration
- **Automatic Backups**: RDB snapshots for persistence

## 🔧 Configuration

### Input Variables

See `variables.tf` for:

- `cluster_id` - Cache cluster name
- `engine_version` - Redis version (e.g., "7.0")
- `node_type` - Instance size (e.g., cache.t3.micro)
- `num_cache_nodes` - Number of nodes for replication
- `parameter_group_name` - Configuration group
- `port` - Redis port (6379)
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:

- `primary_endpoint` - Redis connection endpoint
- `reader_endpoint` - For read-only connections
- `port` - Redis port
- `security_group_id` - For additional access rules

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Scaling Guide](../../runbooks/SCALING.md) - Cache scaling strategies
- [Architecture](../../ARCHITECTURE.md) - System design and caching strategy
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/elasticache/`

**Last updated:** December 2025
