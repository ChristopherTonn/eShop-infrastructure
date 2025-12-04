# RabbitMQ Module

RabbitMQ message broker deployment via Helm.

**Navigation:** [← ElastiCache](ELASTICACHE.md) | [Next: Logging →](LOGGING.md)

---

## 📋 Overview

The RabbitMQ module deploys RabbitMQ as a Kubernetes-based message broker for asynchronous communication between eShop microservices, with clustering, persistence, and management UI.

**Location:** `infra/terraform/modules/rabbitmq/`

## 🏗️ Key Resources

- **Helm Release**: RabbitMQ Helm chart deployment
- **Kubernetes Namespace**: Isolated RabbitMQ environment
- **StatefulSet**: Multi-replica RabbitMQ cluster
- **Persistent Volume Claims**: Data durability across restarts
- **Services**: AMQP (5672) and Management UI (15672)
- **Secrets**: Credentials for authentication
- **ConfigMaps**: RabbitMQ plugins and configuration
- **Health Probes**: Liveness and readiness checks

## 🔧 Configuration

### Input Variables

See `variables.tf` for:

- `namespace` - Kubernetes namespace
- `release_name` - Helm release name
- `replicas` - Number of RabbitMQ nodes (for clustering)
- `storage_size` - Persistent volume size
- `image` / `image_tag` - RabbitMQ version
- `management_user` / `management_password` - Web UI credentials
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:

- `amqp_connection_string` - For service connections
- `management_ui_url` - Web UI access
- `service_name` - Kubernetes service endpoint
- `credentials` - Connection credentials

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Architecture](../../ARCHITECTURE.md) - Event-driven messaging design
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/rabbitmq/`

**Last updated:** December 2025
