# CloudWatch Logging - Quick Start (5 Minutes)

Get centralized logging up and running in 5 minutes.

## Prerequisites (Check Before Starting)

```bash
# 1. Verify EKS cluster is running
kubectl cluster-info

# 2. Verify Terraform is at root directory
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev

# 3. Verify AWS credentials are configured
aws sts get-caller-identity

# 4. Verify AWS region is set correctly
echo $AWS_REGION || echo "NOT SET - set AWS_REGION env var"
```

## Deploy in 5 Minutes

### 1. Edit Configuration (1 minute)

```bash
# Open terraform.tfvars
nano terraform.tfvars  # or vim, code, etc.

# Add these lines (or uncomment if they exist):
logging_enabled                        = true
fluent_bit_enabled                     = true
cloudwatch_log_retention_days          = 7
fluent_bit_enable_container_insights   = true

# Save and exit
```

### 2. Plan Deployment (2 minutes)

```bash
# Plan both modules
terraform plan -target=module.cloudwatch_logging -target=module.fluent_bit

# Review output:
# - Should show ~15 resources to create
# - No errors or warnings
```

### 3. Apply Changes (2 minutes)

```bash
# Deploy CloudWatch Logs infrastructure
terraform apply -target=module.cloudwatch_logging -target=module.fluent_bit

# Type 'yes' when prompted
# Wait for deployment to complete (~1-2 minutes)
```

## Verify Deployment

### Check Log Groups (CloudWatch Console)

```bash
# List log groups from CLI
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/eshop-dev-cluster" \
  --query 'logGroups[].logGroupName' \
  --output table
```

**Expected Output:**

```text
|                              logGroupName                              |
|------------------------------------------------------------------------|
| /aws/eks/eshop-dev-cluster/basket-api                                 |
| /aws/eks/eshop-dev-cluster/catalog-api                                |
| /aws/eks/eshop-dev-cluster/ordering-api                               |
| /aws/eks/eshop-dev-cluster/identity-api                               |
| /aws/eks/eshop-dev-cluster/webhooks-api                               |
| /aws/eks/eshop-dev-cluster/order-processor                            |
| /aws/eks/eshop-dev-cluster/payment-processor                          |
| /aws/eks/eshop-dev-cluster/webapp                                     |
| /aws/eks/eshop-dev-cluster/platform                                   |
```

### Check Fluent Bit Pods

```bash
# Check if pods are running
kubectl get pods -n logging -o wide

# Expected: 1 fluent-bit pod per Kubernetes node, all in "Running" state
```

### Stream Logs Immediately

```bash
# Stream logs from Fluent Bit
kubectl logs -n logging -l app=fluent-bit -f --tail=20

# Successful indicators (look for these messages):
# "[info] Fluent Bit"
# "inputs | tail"
# "filters | kubernetes"
# "outputs | cloudwatch_logs"

# Ctrl+C to stop
```

## View Logs in CloudWatch

### Option 1: AWS Console (Easiest)

1. Open: https://console.aws.amazon.com/cloudwatch/
2. Click: **Logs → Log Groups**
3. Search: `eshop-dev`
4. Click: `/aws/eks/eshop-dev-cluster/basket-api` (or any service)
5. Click on Log Stream with recent timestamp
6. **View logs streaming in real-time!**

### Option 2: CloudWatch Insights Query

```bash
# In CloudWatch console, go to Logs → Insights
# Copy-paste this query:

fields @timestamp, kubernetes.pod_name, @message
| stats count() as log_count by kubernetes.pod_name
```

**Result**: Shows count of logs per pod in the last 1 hour

### Option 3: AWS CLI

```bash
# Get logs from last 10 minutes
aws logs filter-log-events \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --start-time $(( $(date +%s%N) - 10 * 60 * 1000000000 )) \
  --limit 10

# Get only ERROR logs
aws logs filter-log-events \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --filter-pattern "ERROR" \
  --limit 20
```

## Common Queries (Copy-Paste)

Run these in CloudWatch Insights Console (Logs → Insights → Select log group → paste query)

### Find All Errors Last Hour

```sql
fields @timestamp, kubernetes.pod_name, @message
| filter @message like /(?i)error|exception|fail/
| stats count() as errors by kubernetes.pod_name
```

### Compare Services by Log Volume

```sql
fields @timestamp, kubernetes.pod_name
| stats count() as log_count by kubernetes.pod_name
```

### Find Slow Operations (> 100ms)

```sql
fields @timestamp, response_time_ms, @message
| filter response_time_ms > 100
| stats avg(response_time_ms), max(response_time_ms) by kubernetes.pod_name
```

### Monitor Pod Restarts

```sql
fields @timestamp, kubernetes.pod_name
| filter @message like /restart|Terminating/
| stats count() as restart_count by kubernetes.pod_name
```

## Next Steps

### 1. Increase Retention (Optional)

```bash
# Change retention from 7 to 30 days
# Edit terraform.tfvars
cloudwatch_log_retention_days = 30

terraform apply -target=module.cloudwatch_logging
```

### 2. Add Log-Based Alarms

```bash
# Create alarm for high error rates
aws logs put-metric-filter \
  --log-group-name "/aws/eks/eshop-dev-cluster/basket-api" \
  --filter-name "ErrorCount" \
  --filter-pattern "[... , level = ERROR*, ...]" \
  --metric-transformations metricName=ErrorCount,metricValue=1

aws cloudwatch put-metric-alarm \
  --alarm-name "basket-api-errors" \
  --metric-name ErrorCount \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### 3. Enable KMS Encryption (Security)

```bash
# If you need encryption for compliance
# First, ensure KMS key exists, then:

# Edit terraform.tfvars
cloudwatch_enable_kms_encryption = true
cloudwatch_kms_key_arn = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"

terraform apply -target=module.cloudwatch_logging
```

### 4. Integrate with Grafana (Advanced)

Add CloudWatch as a data source in Grafana:

```bash
# Get Fluent Bit role ARN
terraform output logging_deployment_summary | grep fluent_bit_role_arn

# In Grafana:
# 1. Configuration → Data Sources → Add
# 2. Select CloudWatch
# 3. Use IAM role ARN for authentication
# 4. Select region: eu-central-1
```

## Troubleshooting (Most Common Issues)

### Issue: "No logs appearing in CloudWatch"

**Check Fluent Bit status:**

```bash
kubectl describe pod -n logging -l app=fluent-bit

# Look for "Ready 1/1" and "Running" status
# If not, check logs: kubectl logs -n logging -l app=fluent-bit
```

**Verify IRSA is working:**

```bash
kubectl get sa fluent-bit -n logging -o yaml | grep role-arn

# Should show: arn:aws:iam::ACCOUNT:role/eshop-fluent-bit-dev
```

**Check log group exists:**

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/eks/eshop-dev-cluster

# Should list 9 log groups
```

### Issue: "Fluent Bit pod CrashLoopBackOff"

```bash
# Check error in logs
kubectl logs -n logging pod/fluent-bit-xxxxx

# Common causes:
# 1. ServiceAccount IRSA annotation wrong - re-apply Terraform
# 2. Insufficient memory - increase limits in terraform.tfvars
# 3. Helm chart version mismatch - check with: helm list -n logging
```

### Issue: "CloudWatch quota exceeded"

```bash
# If you see this error during terraform apply:
# Solution: Increase log group quota via AWS Service Quotas

aws service-quotas request-service-quota-increase \
  --service-code logs \
  --quota-code L-FE5FBDFE \
  --desired-value 2000
```

## Cleanup (If Needed)

To remove logging (WARNING: Deletes log groups!)

```bash
# Destroy Fluent Bit and CloudWatch
terraform destroy -target=module.fluent_bit -target=module.cloudwatch_logging

# Or in terraform.tfvars set:
logging_enabled = false
fluent_bit_enabled = false

terraform apply
```

## Support & Documentation

- **Full Guide**: See `DEPLOYMENT_GUIDE.md` for complete documentation
- **Module Details**: See `README.md` for architecture and features
- **CloudWatch Docs**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/
- **Fluent Bit**: https://docs.fluentbit.io/

---

**Time to full logging:** ~5 minutes ⏱️  
**Logs visible in CloudWatch:** ~1-2 minutes after deployment  
**Ready for monitoring:** Immediately after Fluent Bit pods start
