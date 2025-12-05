# 🔐 Infrastructure CI/CD - Environment Secrets Setup

This document outlines all required GitHub Secrets for the Infrastructure CI/CD pipelines.

## 📋 Required Secrets Overview

### ✅ For All Environments

| Secret Name | Type | Description | Example |
|-------------|------|-------------|---------|
| `TF_STATE_BUCKET` | String | S3 bucket for Terraform state | `eshop-terraform-state-prod` |
| `AWS_REGION` | String | AWS region | `eu-central-1` |

---

## 🟢 Development Environment

### Secrets Configuration

Create these secrets in GitHub under: **Settings → Environments → dev**

| Secret Name | Description | How to Get |
|-------------|-------------|-----------|
| `AWS_OIDC_ROLE_ARN_DEV` | ARN of IAM role for dev Terraform | See AWS Setup below |
| `KUBECONFIG` | Base64 encoded kubeconfig for dev cluster | `aws eks update-kubeconfig --name eshop-dev-cluster` |

### AWS OIDC Setup for Dev

```bash
# 1. Create IAM Role for GitHub Actions (dev)
aws iam create-role \
  --role-name github-actions-eshop-dev \
  --assume-role-policy-document file://trust-policy.json \
  --region eu-central-1

# 2. Attach Terraform policy
aws iam attach-role-policy \
  --role-name github-actions-eshop-dev \
  --policy-arn arn:aws:iam::AWS_ACCOUNT_ID:policy/TerraformDevPolicy \
  --region eu-central-1

# 3. Get Role ARN
aws iam get-role --role-name github-actions-eshop-dev --query 'Role.Arn'
# Output: arn:aws:iam::123456789012:role/github-actions-eshop-dev
```

**Store as GitHub Secret:**
```
AWS_OIDC_ROLE_ARN_DEV=arn:aws:iam::123456789012:role/github-actions-eshop-dev
```

---

## 🟡 Staging Environment

### Secrets Configuration

Create these secrets in GitHub under: **Settings → Environments → staging**

| Secret Name | Description | How to Get |
|-------------|-------------|-----------|
| `AWS_OIDC_ROLE_ARN_STAGING` | ARN of IAM role for staging Terraform | See AWS Setup below |
| `KUBECONFIG` | Base64 encoded kubeconfig for staging cluster | `aws eks update-kubeconfig --name eshop-staging-cluster` |

### AWS OIDC Setup for Staging

```bash
# 1. Create IAM Role for GitHub Actions (staging)
aws iam create-role \
  --role-name github-actions-eshop-staging \
  --assume-role-policy-document file://trust-policy.json \
  --region eu-central-1

# 2. Attach Terraform policy
aws iam attach-role-policy \
  --role-name github-actions-eshop-staging \
  --policy-arn arn:aws:iam::AWS_ACCOUNT_ID:policy/TerraformStagingPolicy \
  --region eu-central-1

# 3. Get Role ARN
aws iam get-role --role-name github-actions-eshop-staging --query 'Role.Arn'
```

**Store as GitHub Secret:**
```
AWS_OIDC_ROLE_ARN_STAGING=arn:aws:iam::123456789012:role/github-actions-eshop-staging
```

---

## 🔴 Production Environment

### Secrets Configuration

Create these secrets in GitHub under: **Settings → Environments → prod**

| Secret Name | Description | How to Get |
|-------------|-------------|-----------|
| `AWS_OIDC_ROLE_ARN_PROD` | ARN of IAM role for prod Terraform | See AWS Setup below |
| `KUBECONFIG` | Base64 encoded kubeconfig for prod cluster | `aws eks update-kubeconfig --name eshop-prod-cluster` |
| `SLACK_WEBHOOK` | Slack webhook for deployment notifications | Slack App settings |

### AWS OIDC Setup for Production

```bash
# 1. Create IAM Role for GitHub Actions (prod)
aws iam create-role \
  --role-name github-actions-eshop-prod \
  --assume-role-policy-document file://trust-policy.json \
  --region eu-central-1

# 2. Attach Terraform policy (most restrictive)
aws iam attach-role-policy \
  --role-name github-actions-eshop-prod \
  --policy-arn arn:aws:iam::AWS_ACCOUNT_ID:policy/TerraformProdPolicy \
  --region eu-central-1

# 3. Get Role ARN
aws iam get-role --role-name github-actions-eshop-prod --query 'Role.Arn'
```

**Store as GitHub Secret:**
```
AWS_OIDC_ROLE_ARN_PROD=arn:aws:iam::123456789012:role/github-actions-eshop-prod
```

---

## 🔧 AWS OIDC Trust Policy

Create file: `trust-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:ChristopherTonn/eShop-infrastructure:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

---

## 📦 S3 Backend Setup for Terraform State

```bash
# 1. Create S3 bucket
aws s3api create-bucket \
  --bucket eshop-terraform-state-prod \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# 2. Enable versioning
aws s3api put-bucket-versioning \
  --bucket eshop-terraform-state-prod \
  --versioning-configuration Status=Enabled

# 3. Enable encryption
aws s3api put-bucket-encryption \
  --bucket eshop-terraform-state-prod \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# 4. Create DynamoDB table for state locks
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

---

## ✅ Checklist for Setup

- [ ] Create `dev` environment in GitHub
- [ ] Create `staging` environment in GitHub
- [ ] Create `prod` environment in GitHub with approval gates
- [ ] Create AWS OIDC trust policy
- [ ] Create 3 IAM roles (dev, staging, prod)
- [ ] Add GitHub Secrets to each environment
- [ ] Create S3 bucket for Terraform state
- [ ] Create DynamoDB table for state locks
- [ ] Test OIDC authentication: `aws sts get-caller-identity`
- [ ] Run first `infra-ci.yml` workflow manually
- [ ] Test `infra-cd.yml` on dev environment

---

## 🚀 Quick Start - First Deployment

### Step 1: AWS Setup
```bash
# Export your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create OIDC provider if not exists
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>&1 | grep -i "already" || echo "OIDC provider created"
```

### Step 2: GitHub Secrets Setup
```bash
# For each environment: dev, staging, prod
gh secret set AWS_OIDC_ROLE_ARN_DEV \
  --env dev \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-eshop-dev"
```

### Step 3: Test CI Pipeline
```bash
# Push to feature branch to trigger infra-ci.yml
git push origin feature/infra-setup
```

### Step 4: Deploy to Dev
```bash
# Create PR and merge to main to trigger infra-cd.yml
git push origin main
```

---

## 📚 Related Documentation

- AWS IAM OIDC Setup
- Terraform Backend Configuration
- Local Development Guide
- Kubernetes Deployment
