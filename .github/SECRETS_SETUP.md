# GitHub Secrets Configuration Guide

This documentation describes the required GitHub Secrets for the deployment pipeline across different environments.

## Required Secrets (Organization Level)

### 1. AWS OIDC Integration Secrets

#### `AWS_ACCOUNT_ID`
- **Description**: AWS Account ID for ECR access and deployments
- **Value**: 123456789012 (Your 12-digit AWS Account ID)
- **Usage**: ECR login, AssumeRole operations

#### `AWS_ROLE_ARN`
- **Description**: ARN of the IAM Role for GitHub OIDC authentication
- **Value**: `arn:aws:iam::123456789012:role/github-actions-role`
- **Usage**: OIDC token exchange with AWS STS
- **Required Permissions**:
  - `sts:AssumeRoleWithWebIdentity`
  - `ecr:GetAuthorizationToken`
  - `ecr:BatchCheckLayerAvailability`
  - `ecr:PutImage`
  - `ecr:InitiateLayerUpload`
  - `ecr:UploadLayerPart`
  - `ecr:CompleteLayerUpload`

## Environment-specific Secrets (GitHub Environment Level)

### Development Environment (`dev`)

#### Environment Variables (public)

```
AWS_REGION=eu-central-1
ENVIRONMENT=dev
ECR_REGISTRY_PREFIX=dev
KUBERNETES_NAMESPACE=dev
TERRAFORM_BACKEND=s3
TERRAFORM_BACKEND_BUCKET=eshop-tf-state-dev
TERRAFORM_LOCK_TABLE=eshop-tf-locks-dev
```

#### Secrets (encrypted)

| Secret Name | Description | Example Format |
|------------|-------------|---|
| `AWS_DEV_ROLE_ARN` | IAM Role ARN for Dev environment | `arn:aws:iam::123456789012:role/github-actions-dev` |
| `AWS_ECR_REPOSITORY` | ECR Repository Name | `eshop-dev` |
| `KUBE_CONFIG_DEV` | Base64-encoded kubeconfig for Dev cluster | `YXBpVmVyc2lvbjogdjEK...` |
| `DOCKER_BUILD_ARGS` | Build arguments (optional) | JSON format or Key=Value |
| `SLACK_WEBHOOK_URL` | Slack notifications (optional) | `https://hooks.slack.com/services/...` |

## Setup Steps

### 1. Create GitHub Secrets

```bash
# Organization-level secrets (Settings > Secrets and variables > Actions)
gh secret set AWS_ACCOUNT_ID --body "123456789012"
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::123456789012:role/github-actions-role"
```

### 2. Create GitHub Environment

```bash
# Create environment "dev" (Repository > Settings > Environments)
# Then add the following secrets:
gh secret set AWS_DEV_ROLE_ARN --env dev --body "arn:aws:iam::123456789012:role/github-actions-dev"
gh secret set AWS_ECR_REPOSITORY --env dev --body "eshop-dev"
gh secret set KUBE_CONFIG_DEV --env dev --body "$(cat ~/.kube/config | base64)"
```

### 3. AWS IAM Roles Setup

**GitHub Actions OIDC Provider Role** (for token exchange):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ChristopherTonn/eShop*"
        }
      }
    }
  ]
}
```

**Required Permissions for Development Role**:

- ECR: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, etc.
- EKS: `eks:DescribeCluster`, `eks:ListClusters`
- Terraform State: `s3:*` on `arn:aws:s3:::eshop-tf-state-dev*`
- DynamoDB Locking: `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:DeleteItem`

## Best Practices

✅ **Important:**
- Never store secrets in logs or git history
- Rotate secrets regularly
- Principle of least privilege: Only grant necessary permissions
- Separate roles per environment (dev/staging/prod)
- Use OIDC instead of credentials (no hardcoded AWS Access Keys)

## Troubleshooting

### "OIDC token not accepted"
- OIDC Provider must be configured in AWS IAM
- Check repository sub condition

### "ECR push failed"
- Check AWS_ACCOUNT_ID
- Validate AWS_ROLE_ARN permissions
- Does ECR repository exist?

### "Kubernetes deployment failed"
- Is KUBE_CONFIG_DEV in valid format?
- Is cluster access possible from GitHub Actions runner?
