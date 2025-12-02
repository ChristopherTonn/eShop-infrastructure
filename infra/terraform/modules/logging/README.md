# eShop Logging Infrastructure

Centralized logging solution for eShop using AWS CloudWatch Logs and Fluent Bit for log forwarding.

## Overview

This module provides a complete centralized logging stack consisting of:

- **CloudWatch Log Groups**: AWS-native log storage for all application services and platform components
- **Fluent Bit DaemonSet**: Log forwarding agent that collects logs from all containers and forwards them to CloudWatch
- **IAM Integration (IRSA)**: Secure, temporary credential-based access from Fluent Bit pods to CloudWatch

## Architecture

```mermaid
┌────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────── All Namespaces ──────────────────┐ │
│  │                                                          │ │
│  │  ┌──────────────┐                                        │ │
│  │  │ Application  │                                        │ │
│  │  │ Containers   │                                        │ │
│  │  │ (stdout/     │                                        │ │
│  │  │  stderr)     │                                        │ │
│  │  └───────┬──────┘                                        │ │
│  │          │                                              │ │
│  │          │ (/var/log/containers/)                       │ │
│  │          ▼                                              │ │
│  │  ┌──────────────────────────────────────┐              │ │
│  │  │   Fluent Bit DaemonSet               │              │ │
│  │  │   (logging namespace)                │              │ │
│  │  │                                      │              │ │
│  │  │  ┌──────────────────────────────┐  │              │ │
│  │  │  │ Input: tail plugin           │  │              │ │
│  │  │  │ + systemd plugin             │  │              │ │
│  │  │  └───────────┬──────────────────┘  │              │ │
│  │  │              │                     │              │ │
│  │  │  ┌───────────▼──────────────────┐  │              │ │
│  │  │  │ Filter: Kubernetes metadata  │  │              │ │
│  │  │  │ + JSON parsing               │  │              │ │
│  │  │  │ + Exception detection        │  │              │ │
│  │  │  └───────────┬──────────────────┘  │              │ │
│  │  │              │                     │              │ │
│  │  │  ┌───────────▼──────────────────┐  │              │ │
│  │  │  │ Output: CloudWatch Logs      │  │              │ │
│  │  │  │ (IAM IRSA authentication)    │  │              │ │
│  │  │  └──────────────────────────────┘  │              │ │
│  │  └──────────────────────────────────────┘              │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            │                                  │
│                            │ (IAM Role assumption)            │
│                            ▼                                  │
├────────────────────────────────────────────────────────────────┤
│                         AWS                                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         CloudWatch Log Groups                            │ │
│  │  /aws/eks/eshop-dev-cluster/                            │ │
│  │  ├── basket-api                                         │ │
│  │  ├── catalog-api                                        │ │
│  │  ├── ordering-api                                       │ │
│  │  ├── identity-api                                       │ │
│  │  ├── webhooks-api                                       │ │
│  │  ├── order-processor                                    │ │
│  │  ├── payment-processor                                  │ │
│  │  ├── webapp                                             │ │
│  │  └── platform (system/kube-system logs)                 │ │
│  │                                                          │ │
│  │  Each log group:                                         │ │
│  │  - Retention policy (7-365 days, configurable)          │ │
│  │  - Optional KMS encryption                              │ │
│  │  - CloudWatch Insights available                        │ │
│  │  - Metrics and alarms can be configured                 │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Components

### CloudWatch Module (`logging/cloudwatch/`)

Manages AWS CloudWatch infrastructure:

- **Log Groups**: One per application service + one for platform logs
- **IAM Role (IRSA)**: Service account role for Fluent Bit authentication
- **IAM Policy**: CloudWatch Logs write permissions + optional KMS permissions

### Fluent Bit Module (`logging/fluent-bit/`)

Kubernetes-based log forwarding:

- **DaemonSet**: Runs on every Kubernetes node
- **ConfigMap**: Log parsing and routing configuration
- **ServiceAccount**: IRSA-enabled for AWS credential exchange
- **RBAC**: Permissions to read pod metadata from Kubernetes API

## Features

### Log Collection

- **Container Logs**: All stdout/stderr from application pods
- **System Logs**: systemd journal logs from Kubernetes nodes
- **Structured Logs**: JSON parsing for .NET applications
- **Exception Detection**: Multiline parsing for stack traces

### Log Parsing

Fluent Bit includes parsers for:

- **JSON Format**: Standard Docker/Kubernetes container logs
- **.NET Format**: Structured logs from .NET applications
- **RabbitMQ Format**: Message broker logs
- **PostgreSQL Format**: Database logs

### Service Discovery

Automatic routing to correct log group based on container name:

- `basket-api` containers → `/aws/eks/{cluster}/basket-api`
- `catalog-api` containers → `/aws/eks/{cluster}/catalog-api`
- `ordering-api` containers → `/aws/eks/{cluster}/ordering-api`
- And so on for all services...

### Kubernetes Metadata Enrichment

All logs are automatically enriched with:

- Pod name and namespace
- Container name and image
- Node name and instance ID
- Deployment, StatefulSet, or DaemonSet name
- Labels and annotations (when available)

## Deployment

### Prerequisites

- EKS cluster (1.20+)
- Terraform 1.5+
- kubectl access to cluster
- AWS credentials with CloudWatch Logs permissions

### Quick Start

```bash
cd infra/terraform/envs/dev

# Enable logging in terraform.tfvars
cat >> terraform.tfvars << 'EOF'
logging_enabled                        = true
fluent_bit_enabled                     = true
cloudwatch_log_retention_days          = 7
fluent_bit_enable_container_insights   = true
EOF

# Plan and apply
terraform plan -target=module.cloudwatch_logging -target=module.fluent_bit
terraform apply -target=module.cloudwatch_logging -target=module.fluent_bit
```

### Verification

```bash
# Check CloudWatch Log Groups
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/eshop-dev-cluster"

# Check Fluent Bit pod status
kubectl get pods -n logging
kubectl logs -n logging -l app=fluent-bit -f

# Verify IRSA role annotation
kubectl get serviceaccount fluent-bit -n logging -o jsonpath='{.metadata.annotations}'
```

## Configuration

### Terraform Variables

Key variables in `envs/dev/variables.tf`:

```hcl
# Enable/disable logging
logging_enabled                     = true
fluent_bit_enabled                  = true

# CloudWatch configuration
cloudwatch_log_retention_days       = 7   # Valid: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, etc.
cloudwatch_enable_kms_encryption    = false
cloudwatch_kms_key_arn             = ""   # Required if KMS encryption enabled

# Fluent Bit configuration
fluent_bit_chart_version           = "0.21.0"
fluent_bit_image_tag               = "2.1.8"
fluent_bit_buffer_size             = "32m"
fluent_bit_enable_container_insights = true
fluent_bit_enable_multiline_parsing = true

# Resource limits
fluent_bit_resources = {
  requests = {
    cpu    = "100m"
    memory = "128Mi"
  }
  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}
```

### Fluent Bit Configuration

Main configuration in `logging/fluent-bit/values.yaml`:

```yaml
# Service level (global settings)
[SERVICE]
    Flush             5
    Log_Level         info
    HTTP_Server       On
    HTTP_Port         2020

# Input plugins
[INPUT]
    Name    tail           # Read container logs from disk
    Path    /var/log/containers/*.log
    Parser  docker         # Parse JSON format

[INPUT]
    Name    systemd        # Read systemd journal
    Path    /var/log/journal

# Filter plugins
[FILTER]
    Name        kubernetes    # Add Kubernetes metadata
    Match       container.*
    Kube_URL    https://kubernetes.default.svc:443

[FILTER]
    Name        modify        # Add custom fields
    Match       *
    Add         cluster_name ${cluster_name}
    Add         region ${region}

# Output plugins
[OUTPUT]
    Name            cloudwatch_logs
    Match           container.var.log.containers.*basket*.log
    region          ${region}
    log_group_name  /aws/eks/${cluster}/basket-api
```

## CloudWatch Insights Queries

### Find All Errors (Last 1 Hour)

```sql
fields @timestamp, kubernetes.pod_name, @message
| filter @message like /(?i)(error|exception|fail)/
| stats count() by kubernetes.pod_name
```

### Basket API - Response Time Analysis

```sql
fields @timestamp, kubernetes.pod_name, http_status_code, response_time_ms
| filter kubernetes.pod_name like /basket/
| stats avg(response_time_ms), max(response_time_ms), pct(response_time_ms, 95) by http_status_code
```

### RabbitMQ Message Processing

```sql
fields @timestamp, @message, queue_name
| filter kubernetes.pod_name like /rabbitmq/
| stats count() as message_count by queue_name
```

### Pod Restart Tracking

```sql
fields @timestamp, kubernetes.pod_name, kubernetes.namespace_name
| filter @message like /restart|Terminating|CrashLoopBackOff/
| stats count() as restart_count by kubernetes.pod_name
```

### Database Slow Query Detection

```sql
fields @timestamp, @duration_ms, @query
| filter @duration_ms > 1000
| stats count(), avg(@duration_ms) by @query
```

## Monitoring

### CloudWatch Alarms

Create alarms for error rates:

```bash
aws logs put-metric-filter \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --filter-name ErrorCount \
  --filter-pattern "[... , level = ERROR*, ...]" \
  --metric-transformations metricName=ErrorCount,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "basket-api-errors" \
  --metric-name ErrorCount \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

### Prometheus Integration (Future)

Fluent Bit exposes metrics on HTTP port 2020:

```bash
# Port-forward to local machine
kubectl port-forward -n logging -l app=fluent-bit 2020:2020

# Query metrics endpoint
curl http://localhost:2020/api/v1/metrics/prometheus
```

## Grafana Integration

### Add CloudWatch as Data Source

1. Grafana UI → Configuration → Data Sources → Add New
2. Select "CloudWatch"
3. Configure AWS Credentials:
   - Use IAM role ARN from `outputs.logging_deployment_summary.fluent_bit_role_arn`
   - Or configure API key/secret if not using IRSA
4. Select Default Region: eu-central-1 (or your AWS region)

### Create Dashboard from Log Insights

1. CloudWatch Logs Insights Console
2. Run query (see examples above)
3. Click "Add to Dashboard" → Create/Select Grafana Dashboard

### Log Tail Widget

```json
{
  "type": "cloudwatch",
  "targets": [
    {
      "region": "eu-central-1",
      "expression": "fields @timestamp, kubernetes.pod_name, @message | filter kubernetes.namespace_name = 'default' | head 100",
      "id": "q1"
    }
  ]
}
```

## Troubleshooting

### Logs Not Appearing in CloudWatch

1. Check Fluent Bit pod status:

   ```bash
   kubectl describe pod -n logging -l app=fluent-bit
   ```

2. Check Fluent Bit logs:

   ```bash
   kubectl logs -n logging -l app=fluent-bit --tail=100
   ```

3. Verify IAM permissions:

   ```bash
   kubectl get serviceaccount fluent-bit -n logging -o yaml
   # Check if role ARN annotation is present
   ```

4. Check CloudWatch Log Groups:
   ```bash
   aws logs describe-log-groups --query 'logGroups[?contains(logGroupName, `eshop`)]'
   ```

### High Memory Usage in Fluent Bit

1. Increase buffer size limit:

   ```hcl
   fluent_bit_buffer_size = "64m"  # Default: 32m
   terraform apply
   ```

2. Or reduce flush interval:
   ```yaml
   [SERVICE]
       Flush 2  # Flush every 2 seconds (default: 5)
   ```

### IAM Role Issues

1. Verify OIDC Provider is configured:

   ```bash
   aws iam list-open-id-connect-providers
   ```

2. Check ServiceAccount annotation:

   ```bash
   kubectl get sa fluent-bit -n logging -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
   ```

3. Manually test role assumption:
   ```bash
   aws sts assume-role-with-web-identity \
     --role-arn $(kubectl get sa fluent-bit -n logging -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}') \
     --role-session-name test \
     --web-identity-token $(kubectl create token fluent-bit -n logging)
   ```

### Log Parsing Errors

1. Check Fluent Bit parser configuration:

   ```bash
   kubectl exec -it -n logging -l app=fluent-bit -- \
     cat /fluent-bit/etc/fluent-bit.conf | grep -A5 PARSER
   ```

2. Test parser with sample log:
   ```bash
   # Inside Fluent Bit pod
   echo '{"time":"2024-01-01T12:00:00.000Z","level":"ERROR","message":"test"}' | \
     fluent-bit -i exec -p "command=cat" -F parser -p "parser=json" -o stdout
   ```

## Performance Tuning

### For High-Volume Logs

```hcl
fluent_bit_resources = {
  requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

fluent_bit_buffer_size = "64m"
```

### CloudWatch Insights Query Optimization

Use fields and filtering for faster queries:

```sql
fields @timestamp, @message, kubernetes.pod_name
| filter kubernetes.namespace_name = 'default'
| filter @message like /ERROR/
```

Avoid using `stats` without limiting results first.

## Cost Optimization

### Log Retention

Reduce retention to lower storage costs:

```hcl
cloudwatch_log_retention_days = 3  # Default: 7 days
terraform apply
```

### Selective Log Collection

Deploy Fluent Bit with pod-level labels to exclude certain workloads:

```yaml
# In values.yaml
[FILTER]
    Name                kubernetes
    Match               container.*
    Labels              On
    K8S-Logging.Exclude On
```

## Additional Resources

- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS EKS Logging Documentation](https://docs.aws.amazon.com/eks/latest/userguide/logging-awscloudwatch.html)
- [Fluent Bit Kubernetes Plugin](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/storage)
