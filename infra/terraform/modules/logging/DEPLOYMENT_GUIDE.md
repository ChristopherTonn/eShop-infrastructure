# CloudWatch Logging Deployment & Operations Guide

Complete step-by-step guide for deploying, configuring, and operating the CloudWatch Logging infrastructure in eShop Kubernetes clusters.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Deployment via Terraform](#3-deployment-via-terraform)
4. [Verification & Health Checks](#4-verification--health-checks)
5. [CloudWatch Logs Access](#5-cloudwatch-logs-access)
6. [CloudWatch Insights Queries](#6-cloudwatch-insights-queries)
7. [Fluent Bit Configuration](#7-fluent-bit-configuration)
8. [IAM & Security](#8-iam--security)
9. [Monitoring & Alerting](#9-monitoring--alerting)
10. [Troubleshooting](#10-troubleshooting)
11. [Cost Optimization](#11-cost-optimization)
12. [Backup & Retention](#12-backup--retention)

## 1. Prerequisites

### AWS Account Requirements

- CloudWatch Logs service enabled in target AWS region
- AWS IAM permissions to create:
  - CloudWatch Log Groups
  - IAM Roles and Policies
  - KMS keys (if encryption enabled)
- CloudWatch pricing understanding (refer: [CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/))

### Kubernetes Cluster Requirements

- EKS cluster version 1.20 or higher
- IRSA (IAM Roles for Service Accounts) configured with OIDC Provider
- kubectl 1.20+ with cluster access
- Helm 3.10+ installed locally

### Terraform Requirements

- Terraform 1.5+
- AWS provider ~> 5.0
- Kubernetes provider ~> 2.23
- Helm provider ~> 2.10

### Networking Requirements

- Egress access from EKS nodes to CloudWatch Logs endpoint
- If using VPC endpoint: CloudWatch Logs VPC endpoint configured
- NAT Gateway or Internet Gateway for internet-based connectivity

## 2. Architecture Overview

### Deployment Layers

```
Layer 1: Applications
├── Basket API (logs to stdout)
├── Catalog API (logs to stdout)
├── Ordering API (logs to stdout)
└── ... other services

     │
     ▼

Layer 2: Container Runtime
├── Docker log driver (captures stdout/stderr)
└── Logs written to /var/log/containers/*.log

     │
     ▼

Layer 3: Fluent Bit DaemonSet
├── Reads container logs (tail plugin)
├── Adds Kubernetes metadata (kubernetes filter)
├── Parses JSON (parser plugin)
└── Routes to CloudWatch (cloudwatch_logs output)

     │
     ▼

Layer 4: IAM Authentication
├── IRSA: ServiceAccount role assumption
├── Temporary AWS SigV4 credentials
└── Scope limited to CloudWatch Logs

     │
     ▼

Layer 5: AWS CloudWatch
├── Log Groups: /aws/eks/eshop-dev-cluster/{service}
├── Log Streams: from-fluent-bit-{pod-name}
├── Retention Policies: 7-365 days
└── Optional KMS Encryption
```

### Log Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│            Kubernetes Node / Pod                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Application Pods (all namespaces)                    │  │
│  │ ├─ basket-api                                        │  │
│  │ ├─ catalog-api                                       │  │
│  │ ├─ ordering-api                                      │  │
│  │ └─ ... other services                                │  │
│  │                                                      │  │
│  │ Logger Output: stdout/stderr                         │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                             │
│               ▼                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Container Runtime (Docker/containerd)                │  │
│  │ - Captures stdout/stderr                             │  │
│  │ - Writes to /var/log/containers/*.log                │  │
│  │ - JSON format with timestamp, stream, partial flag   │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                             │
│               ▼                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Fluent Bit Pod (logging namespace)                   │  │
│  │                                                      │  │
│  │  tail plugin                                         │  │
│  │  ├─ Path: /var/log/containers/*.log                 │  │
│  │  ├─ Parser: docker (JSON)                            │  │
│  │  └─ Mem_Buf_Limit: 32m                               │  │
│  │                                                      │  │
│  │  kubernetes filter                                   │  │
│  │  ├─ Query Kubernetes API for pod metadata            │  │
│  │  ├─ Enrich logs with pod/namespace/labels            │  │
│  │  └─ Merge with original log                          │  │
│  │                                                      │  │
│  │  modify filter                                       │  │
│  │  ├─ Add: cluster_name                                │  │
│  │  ├─ Add: region                                      │  │
│  │  └─ Add: environment                                 │  │
│  │                                                      │  │
│  │  cloudwatch_logs output                              │  │
│  │  ├─ Pattern match: container.var.log.containers...   │  │
│  │  ├─ Log group routing by service name                │  │
│  │  └─ Log stream: from-fluent-bit-{hostname}           │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                             │
│               │ IAM IRSA Authentication                    │
│               │ (temporary credentials)                    │
│               ▼                                             │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ AWS SigV4 signed requests
                    ▼
        ┌─────────────────────────────────┐
        │ AWS API Endpoint                │
        │ logs.eu-central-1.amazonaws.com │
        └─────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────┐
        │ CloudWatch Logs                 │
        │ /aws/eks/eshop-dev-cluster/     │
        │ ├─ basket-api                   │
        │ ├─ catalog-api                  │
        │ ├─ ordering-api                 │
        │ ├─ identity-api                 │
        │ ├─ webhooks-api                 │
        │ ├─ order-processor              │
        │ ├─ payment-processor            │
        │ ├─ webapp                       │
        │ └─ platform                     │
        └─────────────────────────────────┘
```

## 3. Deployment via Terraform

### Step 3.1: Prepare Configuration

```bash
# Navigate to development environment
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with logging configuration
cat >> terraform.tfvars << 'EOF'
# ============================================================================
# Logging Configuration
# ============================================================================

logging_enabled                        = true
fluent_bit_enabled                     = true

# CloudWatch Log retention (days)
# Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
cloudwatch_log_retention_days          = 7

# Optional: KMS encryption for logs (requires KMS key)
cloudwatch_enable_kms_encryption       = false
cloudwatch_kms_key_arn                 = ""

# Fluent Bit configuration
fluent_bit_chart_version               = "0.21.0"
fluent_bit_image_tag                   = "2.1.8"
fluent_bit_buffer_size                 = "32m"
fluent_bit_enable_container_insights   = true
fluent_bit_enable_multiline_parsing    = true

# Resource allocation
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
EOF
```

### Step 3.2: Review Terraform Plan

```bash
# Plan CloudWatch module deployment
terraform plan -target=module.cloudwatch_logging

# Expected output:
# - aws_cloudwatch_log_group.service_logs[*] (8 resources)
# - aws_cloudwatch_log_group.platform_logs
# - aws_iam_role.fluent_bit
# - aws_iam_role_policy.fluent_bit_cloudwatch
```

### Step 3.3: Apply Terraform Configuration

```bash
# Apply CloudWatch logging module
terraform apply -target=module.cloudwatch_logging

# Output will show:
# - Log group names
# - IAM role ARN for Fluent Bit
# - Deployment summary
```

### Step 3.4: Deploy Fluent Bit Helm Release

```bash
# Plan Fluent Bit deployment
terraform plan -target=module.fluent_bit

# Expected output:
# - kubernetes_namespace.logging
# - kubernetes_service_account.fluent_bit
# - helm_release.fluent_bit
# - kubernetes_config_map.fluent_bit_custom
```

```bash
# Apply Fluent Bit deployment
terraform apply -target=module.fluent_bit

# Expected deployment time: 1-2 minutes
```

### Step 3.5: Complete Integration

```bash
# Apply both modules together
terraform apply -target=module.cloudwatch_logging -target=module.fluent_bit

# Or apply entire dev environment
terraform apply
```

## 4. Verification & Health Checks

### Check CloudWatch Log Groups

```bash
# List all eShop log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/eshop-dev-cluster" \
  --region eu-central-1

# Expected output:
# - 8 application service log groups
# - 1 platform log group
# - All with correct retention period
```

### Check Fluent Bit Pod Status

```bash
# Get pods in logging namespace
kubectl get pods -n logging -o wide

# Expected:
# NAME                    READY   STATUS    RESTARTS   AGE
# fluent-bit-xxxx1        1/1     Running   0          2m
# fluent-bit-xxxx2        1/1     Running   0          2m
# ...

# Fluent Bit deploys as DaemonSet, so 1 pod per node
```

### Check Fluent Bit Logs for Errors

```bash
# Stream logs from one Fluent Bit pod
kubectl logs -n logging -l app=fluent-bit --tail=50 -f

# Successful startup indicators:
# [2024/01/15 10:30:00] [ info] Configuration:
# [2024/01/15 10:30:00] [ info]  INPUT
# [2024/01/15 10:30:00] [ info]   name   : tail
# [2024/01/15 10:30:00] [ info]   path   : /var/log/containers/*.log
```

### Verify IAM Role Annotation

```bash
# Check ServiceAccount IRSA annotation
kubectl get serviceaccount fluent-bit -n logging -o yaml

# Expected annotation:
# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/eshop-fluent-bit-dev
```

### Test CloudWatch Connectivity

```bash
# Port-forward to Fluent Bit metrics endpoint
kubectl port-forward -n logging -l app=fluent-bit 2020:2020 &

# Query metrics
curl http://localhost:2020/api/v1/metrics/prometheus | grep output_proc

# Expected: output_proc_records > 0 (logs processed)
```

## 5. CloudWatch Logs Access

### AWS Console Access

1. Open AWS CloudWatch Console: https://console.aws.amazon.com/cloudwatch/
2. Navigate to: Logs → Log Groups
3. Search for: `/aws/eks/eshop-dev-cluster`
4. Click on service log group (e.g., `basket-api`)
5. View Log Streams with recent log entries

### AWS CLI Access

```bash
# Describe a specific log group
aws logs describe-log-group \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api"

# List log streams
aws logs describe-log-streams \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --order-by LastEventTime \
  --descending

# Get recent log events (last 100)
aws logs filter-log-events \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --limit 100 \
  --interleaved \
  --start-time $(date -d '1 hour ago' +%s)000

# Get log events with pattern matching
aws logs filter-log-events \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --filter-pattern "ERROR" \
  --limit 50
```

### Local Log Streaming (kubectl)

```bash
# Stream logs from a specific pod
kubectl logs -n default deployment/basket-api -f

# Compare with CloudWatch using Fluent Bit metrics
kubectl logs -n logging -l app=fluent-bit -f | grep "output"
```

## 6. CloudWatch Insights Queries

### 6.1 Cross-Service Error Analysis

```
fields @timestamp, kubernetes.pod_name, @message
| filter @message like /(?i)(error|exception|fail|critical)/
| stats count() as error_count by kubernetes.pod_name
| sort error_count desc
```

### 6.2 Service-Specific Logs (Example: Basket API)

```
fields @timestamp, @message, kubernetes.pod_name, kubernetes.container_name
| filter kubernetes.pod_name like /basket/
| stats count() by kubernetes.pod_name
```

### 6.3 HTTP Status Code Distribution

```
fields @timestamp, http_status_code
| stats count() as request_count by http_status_code
| sort request_count desc
```

### 6.4 Slow Requests (> 1 second)

```
fields @timestamp, kubernetes.pod_name, @duration_ms
| filter @duration_ms > 1000
| stats count(), avg(@duration_ms), max(@duration_ms), min(@duration_ms) by kubernetes.pod_name
```

### 6.5 Database Errors

```
fields @timestamp, @message, kubernetes.pod_name
| filter @message like /(?i)(database|sql|connection|timeout)/
| stats count() as db_error_count by kubernetes.pod_name
```

### 6.6 RabbitMQ Message Queue Analysis

```
fields @timestamp, queue_name, message_count
| filter kubernetes.pod_name like /rabbitmq/
| stats sum(message_count) as total_messages, avg(message_count) by queue_name
```

### 6.7 Pod Restart Detection

```
fields @timestamp, kubernetes.pod_name, kubernetes.namespace_name
| filter @message like /(?i)(restarting|restart|terminating|crash)/
| stats count() as restart_count by kubernetes.pod_name
```

### 6.8 Application Startup Logs

```
fields @timestamp, kubernetes.pod_name, @message
| filter @message like /(?i)(started|initialization|bootstrap|listening|ready)/
| stats latest(@timestamp) as last_startup by kubernetes.pod_name
```

## 7. Fluent Bit Configuration

### Configuration File Location

```
Pod: fluent-bit-xxxxx (any pod in logging namespace)
Main Config: /fluent-bit/etc/fluent-bit.conf
Custom Parsers: /fluent-bit/etc/custom-parsers.conf
```

### Read Configuration from Pod

```bash
# View main configuration
kubectl exec -it -n logging -l app=fluent-bit \
  -- cat /fluent-bit/etc/fluent-bit.conf

# View custom parsers
kubectl exec -it -n logging -l app=fluent-bit \
  -- cat /fluent-bit/etc/custom-parsers.conf

# View Helm values
kubectl get configmap -n logging -l app=fluent-bit -o yaml
```

### Update Fluent Bit Configuration

To modify log parsing or routing:

```bash
# Edit custom parsers in Terraform
vim /infra/terraform/modules/logging/fluent-bit/custom-parsers.conf

# Or update Helm values
vim /infra/terraform/modules/logging/fluent-bit/values.yaml

# Apply changes
terraform apply -target=module.fluent_bit
```

### Common Configuration Changes

#### 1. Change Log Retention

```hcl
# In envs/dev/terraform.tfvars
cloudwatch_log_retention_days = 30  # Change from 7 to 30 days

terraform apply -target=module.cloudwatch_logging
```

#### 2. Increase Buffer Size for High-Volume Logs

```hcl
fluent_bit_buffer_size = "64m"  # Increase from 32m

terraform apply -target=module.fluent_bit
```

#### 3. Enable KMS Encryption

```hcl
cloudwatch_enable_kms_encryption = true
cloudwatch_kms_key_arn           = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

terraform apply -target=module.cloudwatch_logging
```

## 8. IAM & Security

### IAM Role Structure

```
Role: eshop-fluent-bit-dev
├── Trust Policy
│   └── Allow IRSA: ServiceAccount fluent-bit in logging namespace
│
├── Policy 1: CloudWatch Logs Write
│   ├── logs:CreateLogStream
│   ├── logs:CreateLogGroup
│   ├── logs:PutLogEvents
│   ├── logs:DescribeLogGroups
│   └── Resource: /aws/eks/eshop-dev-cluster/*
│
└── Policy 2: KMS Encryption (if enabled)
    ├── kms:Decrypt
    ├── kms:GenerateDataKey
    └── Resource: arn:aws:kms:region:account:key/id
```

### View IAM Role Details

```bash
# Get role ARN
ROLE_ARN=$(terraform output -raw fluent_bit_deployment_info | jq -r '.role_arn')
echo $ROLE_ARN

# Describe role
aws iam get-role --role-name eshop-fluent-bit-dev

# List attached policies
aws iam list-role-policies --role-name eshop-fluent-bit-dev

# View policy details
aws iam get-role-policy \
  --role-name eshop-fluent-bit-dev \
  --policy-name eshop-fluent-bit-cloudwatch-policy-dev
```

### Test IRSA Credential Exchange

```bash
# Get ServiceAccount token
TOKEN=$(kubectl create token fluent-bit -n logging)
echo $TOKEN

# Assume role using token
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::123456789012:role/eshop-fluent-bit-dev \
  --role-session-name test-session \
  --web-identity-token $TOKEN

# Expected: Returns temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)
```

## 9. Monitoring & Alerting

### CloudWatch Metrics for Fluent Bit

Fluent Bit exposes metrics on port 2020:

```bash
# Forward port
kubectl port-forward -n logging -l app=fluent-bit 2020:2020

# Query output records processed
curl http://localhost:2020/api/v1/metrics/prometheus | grep -E "output.*records"

# Expected output (example):
# fluentbit_output_proc_records_total{plugin_id="0",plugin_name="cloudwatch_logs",name="cloudwatch_logs.0"} 12345
```

### Create CloudWatch Metric Filter for Error Rates

```bash
# Create metric filter for ERROR in logs
aws logs put-metric-filter \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --filter-name "ErrorCount" \
  --filter-pattern "[... , level = ERROR*, ...]" \
  --metric-transformations metricName=ErrorCount,metricValue=1,defaultValue=0

# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "basket-api-error-rate-high" \
  --alarm-description "Alert when basket-api error rate is high" \
  --metric-name ErrorCount \
  --namespace AWS/Logs \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### Prometheus Integration (from monitoring module)

Add Fluent Bit metrics to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: fluent-bit
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - logging
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: fluent-bit
      - source_labels: [__meta_kubernetes_pod_container_port_number]
        action: keep
        regex: "2020"
```

## 10. Troubleshooting

### Issue: Logs Not Appearing in CloudWatch

**Symptoms**: CloudWatch log groups exist but no log entries appear

**Diagnostics**:

```bash
# 1. Check Fluent Bit pod status
kubectl get pods -n logging -o wide
kubectl describe pod -n logging -l app=fluent-bit | head -50

# 2. Check Fluent Bit logs for errors
kubectl logs -n logging -l app=fluent-bit --tail=100 | grep -i error

# 3. Verify ServiceAccount IRSA annotation
kubectl get sa fluent-bit -n logging -o yaml

# 4. Check IAM role exists and is accessible
ROLE_ARN=$(kubectl get sa fluent-bit -n logging -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
aws iam get-role --role-name $(echo $ROLE_ARN | awk -F'/' '{print $NF}')

# 5. Test token generation and role assumption
kubectl create token fluent-bit -n logging | cut -d'.' -f1-2 | base64 -d | jq .
```

**Solutions**:

- If pod is not running: `kubectl logs -n logging pod-name` to see startup errors
- If IRSA annotation missing: Re-apply Terraform: `terraform apply -target=module.fluent_bit`
- If logs show "AccessDenied": Check IAM policy allows CloudWatch Logs writes

### Issue: High Memory Usage in Fluent Bit

**Symptoms**: Fluent Bit pods using > 500MB memory, possible OOM kills

**Diagnostics**:

```bash
# Check current memory usage
kubectl top pods -n logging -l app=fluent-bit

# Check for OOM events
kubectl describe pod -n logging -l app=fluent-bit | grep -i "oom\|out of memory"

# Check container resource limits
kubectl get pod -n logging -l app=fluent-bit -o jsonpath='{.items[].spec.containers[].resources}'
```

**Solutions**:

```hcl
# Increase memory limits in terraform.tfvars
fluent_bit_resources = {
  requests = {
    cpu    = "200m"
    memory = "256Mi"  # Increase from 128Mi
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"    # Increase from 512Mi
  }
}

terraform apply -target=module.fluent_bit
```

Alternatively, reduce log verbosity:

```yaml
# In values.yaml
[SERVICE]
    Log_Level info  # Change from debug to info
```

### Issue: Missing Kubernetes Metadata in Logs

**Symptoms**: Logs appear in CloudWatch but lack pod_name, namespace, labels

**Diagnostics**:

```bash
# Check Kubernetes filter configuration
kubectl exec -it -n logging -l app=fluent-bit \
  -- grep -A10 "\[FILTER\]" /fluent-bit/etc/fluent-bit.conf | grep -A10 kubernetes

# Verify Kubernetes API connectivity
kubectl exec -it -n logging -l app=fluent-bit \
  -- curl -k https://kubernetes.default.svc:443/api/v1/namespaces --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
```

**Solutions**:

- Check RBAC permissions: `kubectl get clusterrolebindings | grep fluent-bit`
- Verify ServiceAccount has cluster-reader role
- Re-apply Terraform RBAC configuration: `terraform apply -target=module.fluent_bit`

### Issue: IAM Role Assumption Failing

**Symptoms**: Logs show "UnrecognizedClientException" or "InvalidClientTokenId"

**Diagnostics**:

```bash
# 1. Check OIDC Provider exists
aws iam list-open-id-connect-providers

# 2. Verify OIDC Provider matches cluster
OIDC_PROVIDER=$(aws eks describe-cluster --name eshop-dev-cluster --query cluster.identity.oidc.issuer --output text | cut -d'/' -f5)
aws iam get-open-id-connect-provider-thumbprint-list \
  --open-id-connect-provider-arn "arn:aws:iam::ACCOUNT:oidc-provider/${OIDC_PROVIDER}"

# 3. Check token validity
kubectl create token fluent-bit -n logging | jq -R 'split(".")[1] | @base64d' | jq .
```

**Solutions**:

- Verify EKS module correctly set up OIDC: `terraform output -raw eks_oidc_provider_arn`
- Ensure Terraform IRSA configuration matches: `terraform show | grep oidc`

### Issue: CloudWatch Log Group Quota Exceeded

**Symptoms**: Terraform shows "ResourceLimitExceededException"

**Note**: AWS limits 1000 log groups per account per region by default

**Solutions**:

1. Request quota increase via AWS Service Quotas:
   ```bash
   aws service-quotas list-services | grep -i logs
   aws service-quotas get-service-quota \
     --service-code logs \
     --quota-code L-FE5FBDFE
   ```

2. Or consolidate log groups by namespace instead of service:
   ```hcl
   # Instead of per-service, use per-namespace
   log_groups = {
     "default" = { ... }
     "platform" = { ... }
   }
   ```

## 11. Cost Optimization

### Log Retention Strategy

```bash
# Calculate storage cost
# Formula: GB stored * $0.50 (approximate per month)

# For 100 services with average 10 MB/hour logs:
# Daily: 100 * 10 MB * 24 = 24 GB
# Monthly (30 days): 720 GB = ~$360/month

# To reduce costs:
# Option 1: Reduce retention
cloudwatch_log_retention_days = 3  # Keep only 3 days

# Option 2: Filter non-critical logs
# Add filter to exclude DEBUG logs
[FILTER]
    Name        grep
    Match       *
    Exclude     level DEBUG
```

### Selective Log Collection

Only collect logs from important services:

```yaml
# In Fluent Bit values.yaml
[FILTER]
    Name        kubernetes
    Match       container.*
    K8S-Logging.Exclude On
    # Add additional excludes for non-essential workloads
```

### Use CloudWatch Logs Data Protection

Automatically mask sensitive data (PII) before storage:

```bash
aws logs put-data-protection-policy \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --data-protection-policy file://policy.json
```

### Archive Old Logs

```bash
# Export logs to S3 after 30 days (cheaper storage)
aws logs create-export-task \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --from $(date -d '30 days ago' +%s)000 \
  --to $(date +%s)000 \
  --destination "my-bucket" \
  --destination-prefix "eshop-logs-archive"
```

## 12. Backup & Retention

### Backup CloudWatch Log Configuration

```bash
# Export all log groups configuration
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/eshop-dev-cluster" \
  > cloudwatch-logs-backup.json

# Export all metric filters
for lg in $(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text); do
  aws logs describe-metric-filters --log-group-name "$lg" >> metric-filters-backup.json
done
```

### Retention Policy Changes

```hcl
# Gradually reduce retention as logs age
# Day 1-7: retention_days = 7
# Day 8-30: Archive to S3
# Day 31+: Delete from CloudWatch

# In Terraform, change retention in phases
cloudwatch_log_retention_days = 3  # Initial: 3 days in CloudWatch
```

### Disaster Recovery

To recreate log groups in another region:

```bash
# Export configuration from source region
aws logs describe-log-groups \
  --region eu-central-1 \
  --query 'logGroups[].[logGroupName,retentionInDays]' \
  > logs-config.txt

# Recreate in target region
while read lg retention; do
  aws logs create-log-group \
    --region eu-west-1 \
    --log-group-name "$lg"
  aws logs put-retention-policy \
    --region eu-west-1 \
    --log-group-name "$lg" \
    --retention-in-days "$retention"
done < logs-config.txt
```

---

## Additional Resources

- [AWS CloudWatch Logs User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [Fluent Bit Official Documentation](https://docs.fluentbit.io/)
- [CloudWatch Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS EKS Best Practices Guide - Logging](https://aws.github.io/aws-eks-best-practices/scalability/core-objects/logging/)
- [eShop Infrastructure README](../../../README.md)
