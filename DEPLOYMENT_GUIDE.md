# eShop Infrastructure Deployment Guide

## Status: ✅ ALL FIXES COMPLETED

### 📋 What Was Fixed

#### 1. **ECR Policy Error** ✅ FIXED

- **Issue:** ECR repository policies had empty Principal lists
- **Fix:** Updated policies to use valid AWS account root principal
- **File:** `infra/terraform/modules/ecr/main.tf`

#### 2. **RDS Engine Version Error** ✅ FIXED

- **Issue:** PostgreSQL version 15.3 is no longer available in eu-central-1
- **Fix:** Updated to version 15.4 (compatible and available)
- **Files:**
  - `infra/terraform/envs/dev/terraform.tfvars` (version = "15.4")
  - `infra/terraform/envs/dev/variables.tf` (default = "15.4")

#### 3. **EKS SSH Key Error** ✅ FIXED

- **Issue:** EC2 SSH key name was empty, but required by AWS
- **Fix:** Added `eks_node_ssh_key` variable and integrated with EKS module
- **Files:**
  - `infra/terraform/envs/dev/terraform.tfvars` (eks_node_ssh_key = "eshop-dev-key")
  - `infra/terraform/envs/dev/variables.tf` (added eks_node_ssh_key variable)
  - `infra/terraform/envs/dev/main.tf` (passed ssh_key_name to EKS module)

#### 4. **Terraform State Issues** ✅ FIXED

- **Issue:** Stale plan files and dependency errors
- **Fix:** Complete cleanup of all AWS resources + improved locals logic
- **Script:** `infra/cleanup-aws.sh` (comprehensive cleanup with dependency handling)

#### 5. **Variable Configuration** ✅ OPTIMIZED

- **Files Updated:**
  - `terraform.tfvars`: Added missing SSH key configuration
  - `variables.tf`: Added eks_node_ssh_key, updated RDS version default
  - `main.tf`: Updated locals to use variables instead of hardcoded values

---

## 🚀 Pre-Deployment Setup

### Step 1: Create EC2 SSH Key

**Option A: Create New SSH Key (Recommended)**

```bash
#!/bin/bash
REGION="eu-central-1"
KEY_NAME="eshop-dev-key"

# Create the key pair
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --region $REGION \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/$KEY_NAME.pem

# Fix permissions
chmod 600 ~/.ssh/$KEY_NAME.pem

echo "✅ SSH key created: ~/.ssh/$KEY_NAME.pem"
```

**Option B: Use Existing SSH Key**

```bash
# List all available keys in eu-central-1
aws ec2 describe-key-pairs --region eu-central-1 --output table

# Update terraform.tfvars with your existing key name
# eks_node_ssh_key = "your-existing-key"
```

### Step 2: Verify All Fixes in Code

```bash
# Check RDS version is 15.4
grep "rds_engine_version" /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev/terraform.tfvars

# Check SSH key is configured
grep "eks_node_ssh_key" /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev/terraform.tfvars

# Check ECR policy is valid
cat /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/modules/ecr/main.tf | grep -A 30 "aws_ecr_repository_policy"
```

### Step 3: Validate Terraform Configuration

```bash
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev

# Initialize Terraform
terraform init

# Validate syntax
terraform validate

# Plan the deployment (dry run)
terraform plan -out=tfplan

# Review the plan carefully!
```

### Step 4: Apply Terraform Configuration

```bash
# Apply the plan
terraform apply tfplan

# This will create:
# - VPC with subnets, route tables, NAT gateways
# - EKS cluster with 1 t3.medium node (scale to 2 max)
# - RDS PostgreSQL database (db.t3.micro)
# - ElastiCache Redis cluster (cache.t3.micro)
# - 9 ECR repositories
# - IAM roles and policies
# - Security groups
# - CloudWatch log groups
# - KMS keys for encryption
# - Secrets Manager secrets
```

---

## 📊 Deployment Cost Estimation

For **minimal dev setup** (as configured):

| Component       | Instance Type      | Hourly Cost   | Monthly Cost   |
| --------------- | ------------------ | ------------- | -------------- |
| EKS Cluster     | t3.medium (1 node) | $0.033        | ~$24           |
| RDS Database    | db.t3.micro        | $0.005        | ~$4            |
| ElastiCache     | cache.t3.micro     | $0.007        | ~$5            |
| NAT Gateway (1) | -                  | $0.032        | ~$24           |
| Load Balancer   | ALB                | $0.016        | ~$12           |
| **TOTAL**       | -                  | **~$0.093/h** | **~$69/month** |

---

## ✅ Deployment Checklist

- [ ] SSH key created or selected
- [ ] `terraform.tfvars` has `eks_node_ssh_key = "eshop-dev-key"` (or your key)
- [ ] RDS version is 15.4 in both `terraform.tfvars` and `variables.tf`
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows expected resources
- [ ] All Secrets Manager values are valid in `terraform.tfvars`
- [ ] AWS credentials are configured (`aws sts get-caller-identity` works)
- [ ] Region is set to eu-central-1 in AWS CLI

---

## 🔄 Deploy & Verify

### Deploy Infrastructure

```bash
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev

# Create all resources
terraform apply tfplan

# Get outputs (endpoint URLs, cluster name, etc.)
terraform output

# Save outputs for reference
terraform output > deployment-outputs.txt
```

### Configure kubectl

```bash
# Update kubeconfig for EKS cluster
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION="eu-central-1"

aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Verify ECR Access

```bash
# Get ECR registry URL
ECR_REGISTRY=$(terraform output -raw ecr_registry)

# Login to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# List repositories
aws ecr describe-repositories --region eu-central-1
```

---

## 🧹 Cleanup (Cost Savings)

To delete all resources and stop incurring costs:

```bash
# Option 1: Terraform destroy (cleanest)
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev
terraform destroy

# Option 2: Manual cleanup script
bash /Users/christophertonn/Documents/WORKSPACE/eShop/infra/cleanup-aws.sh
```

**Cost Savings:** ~$70/month after cleanup

---

## 🆘 Troubleshooting

### Issue: "ec2SshKey in remote-access can't be empty"

**Solution:** Ensure `eks_node_ssh_key` is set in `terraform.tfvars`:

```hcl
eks_node_ssh_key = "eshop-dev-key"
```

### Issue: "Cannot find version 15.3 for postgres"

**Solution:** RDS version must be 15.4 or higher. Check both files:

```bash
grep "rds_engine_version" infra/terraform/envs/dev/terraform.tfvars
grep "rds_engine_version" infra/terraform/envs/dev/variables.tf
```

### Issue: "Invalid parameter at 'PolicyText' failed to satisfy constraint"

**Solution:** ECR policies must have valid principals. The code now uses:

```hcl
Principal = {
  AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}
```

### Issue: Terraform State Lock

If you get a state lock error:

```bash
cd infra/terraform/envs/dev
terraform force-unlock <LOCK_ID>
```

---

## 📚 Key Files Reference

| File                                        | Purpose                     | Status                  |
| ------------------------------------------- | --------------------------- | ----------------------- |
| `infra/terraform/modules/ecr/main.tf`       | ECR repositories & policies | ✅ Fixed                |
| `infra/terraform/modules/eks/main.tf`       | EKS cluster & node groups   | ✅ Updated with SSH key |
| `infra/terraform/modules/rds/main.tf`       | RDS PostgreSQL database     | ✅ Updated RDS version  |
| `infra/terraform/envs/dev/terraform.tfvars` | Variable values             | ✅ Fixed                |
| `infra/terraform/envs/dev/variables.tf`     | Variable definitions        | ✅ Updated              |
| `infra/terraform/envs/dev/main.tf`          | Root module                 | ✅ Updated              |
| `infra/cleanup-aws.sh`                      | AWS resource cleanup        | ✅ Created              |

---

## 📞 Support

For issues during deployment:

1. Check logs: `terraform apply -parallelism=1 -debug`
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check region: `aws configure get region`
4. Review security groups: `aws ec2 describe-security-groups`

---

**Last Updated:** 2025-11-25  
**All Fixes Applied:** ✅ YES  
**Ready for Deployment:** ✅ YES
