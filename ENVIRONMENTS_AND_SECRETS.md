# Environments and Secrets Configuration

This documentation describes the complete configuration for Dev/Stage/Prod environments and secrets management.

## Overview

The eShop project uses the following technologies for environment and secrets management:

- **GitHub Environments**: Für Environment-spezifische Variablen und Secrets
- **AWS Secrets Manager**: Zentrale Speicherung von Secrets (Credentials, Keys, etc.)
- **Kubernetes CSI Driver**: Integration von AWS Secrets Manager in K8s Pods
- **Terraform**: Infrastructure-as-Code mit S3 Backend und DynamoDB Locking

## 1. Architecture Overview

```mermaid
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐         │
│  │ Branch Sync │→ │ CI Pipeline  │→ │ CD Pipeline │         │
│  └─────────────┘  └──────────────┘  └─────────────┘         │
│        │                │                   │                │
│    develop       oshop-dev-eks          deploy to K8s        │
└────────┼────────────────┼───────────────────┼────────────────┘
         │                │                   │
         ↓                ↓                   ↓
   GitHub                AWS            Kubernetes
   Secrets         Secrets Manager      CSI Driver
                                        ↓
                                   Pod Volumes
                                   Environment
                                   Variables
```

## 2. GitHub Secrets Configuration

### 2.1 Organization-Level Secrets

These secrets are required for all environments:

| Secret           | Description                    | Security          |
| ---------------- | ------------------------------ | ----------------- |
| `AWS_ACCOUNT_ID` | AWS Account ID (12 digits)     | Publicly readable |
| `AWS_ROLE_ARN`   | ARN of GitHub Actions IAM Role | Publicly readable |

**Setup:**

```bash
# Go to: Settings → Secrets and variables → Actions
gh secret set AWS_ACCOUNT_ID --body "123456789012"
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::123456789012:role/github-actions-role"
```

#### 2.2 Environment-Level Secrets (Dev)

**Environment: `dev`**

Deployment Branch: `develop`

**Public Environment Variables:**

```bash
AWS_REGION=eu-central-1
ENVIRONMENT=dev
ECR_REGISTRY_PREFIX=dev
KUBERNETES_NAMESPACE=dev
KUBERNETES_CLUSTER_NAME=eshop-dev-eks
TERRAFORM_BACKEND=s3
TERRAFORM_BACKEND_BUCKET=eshop-tf-state-dev
TERRAFORM_LOCK_TABLE=eshop-tf-locks-dev
TERRAFORM_WORKSPACE=dev
```

**Environment Secrets (encrypted):**

```bash
AWS_DEV_ROLE_ARN          # IAM Role for Dev deployments
AWS_ECR_REPOSITORY        # ECR Repository Name
KUBE_CONFIG_DEV          # Base64-encoded kubeconfig
SLACK_WEBHOOK_URL        # Optional: Slack notifications
```

## 3. AWS Secrets Manager

### 3.1 Secrets Structure

All secrets follow this naming pattern: `eshop-{environment}/{service}/{secret-type}`

```text
eshop-dev/
├── rds/
│   └── credentials          # {username, password}
├── redis/
│   └── credentials          # password
├── identity/
│   └── jwt-secret          # JWT signing key
├── rabbitmq/
│   └── credentials         # {username, password}
└── api-keys/               # {api_key_1, api_key_2, ...}

eshop-staging/
└── (same structure)

eshop-prod/
└── (same structure)
```

### 3.2 Terraform Secrets Manager Integration

The `secrets-manager` module creates and manages all secrets:

**Location:** `/infra/terraform/modules/secrets-manager/`

**Usage in Dev Environment:**

```hcl
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment = "dev"
  name_prefix = "eshop-dev"

  # Credentials
  rds_username  = "postgres"
  rds_password  = var.rds_master_password

  jwt_secret = var.jwt_signing_secret

  rabbitmq_username = "guest"
  rabbitmq_password = var.rabbitmq_password

  tags = {
    Environment = "development"
  }
}
```

## 4. Kubernetes CSI Driver Integration

### 4.1 Installation

The CSI Driver module installs and configures:

- **Secrets Store CSI Driver**: Kubernetes component for secret mounting
- **AWS Secrets Store Provider**: AWS-specific provider
- **IRSA Service Account**: IAM role for pod access

**Module:** `/infra/terraform/modules/k8s-csi-driver/`

### 4.2 SecretProviderClass Beispiele

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: eshop-rds-secrets
  namespace: eshop-dev
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "eshop-dev/rds/credentials"
        objectType: "secretsmanager"
        objectAlias: "db-credentials"
```

**Usage in Pod:**

```yaml
containers:
  - name: basket-api
    volumeMounts:
      - name: rds-secrets
        mountPath: /mnt/secrets/rds
        readOnly: true

volumes:
  - name: rds-secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "eshop-rds-secrets"
```

**Files:**

- `/infra/k8s/secrets-provider-classes.yaml` - SecretProviderClass Definitions
- `/infra/k8s/example-pod-with-secrets.yaml` - Pod example

## 5. Terraform Backend Configuration

### 5.1 Bootstrap (State Management)

The bootstrap must be executed before infrastructure deployment:

```bash
cd infra/terraform/bootstrap

# Initialize and deploy
terraform init
terraform plan
terraform apply

# S3 buckets and DynamoDB tables will be created:
# - eshop-terraform-state-dev
# - eshop-terraform-lock-dev
# - eshop-terraform-state-staging
# - eshop-terraform-lock-staging
# - eshop-terraform-state-prod
# - eshop-terraform-lock-prod
```

### 5.2 Backend Configuration per Environment

The Dev environment is already configured:

```hcl
terraform {
  backend "s3" {
    bucket         = "eshop-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-terraform-lock-dev"
    encrypt        = true
  }
}
```

## 6. Deployment Workflow

### 6.1 CI/CD Pipeline

```
1. Git Push (develop/staging/main)
   ↓
2. GitHub Actions Trigger (CI Workflow)
   ├─ Code Build
   ├─ Tests
   └─ Docker Image → ECR
   ↓
3. CD Workflow (Approval für Dev)
   ├─ Get Environment Secrets
   ├─ Assume AWS Role (via OIDC)
   ├─ Deploy to EKS
   └─ Update Kubernetes Secrets
   ↓
4. Kubernetes
   ├─ Pull Docker Image
   ├─ Mount CSI Secrets
   ├─ Initialize Container
   └─ Start Service
```

### 6.2 Secret Resolution in K8s

```
Pod Start
↓
K8s reads SecretProviderClass
↓
CSI Driver contacts AWS Secrets Manager
↓
Fetch Secret (with IAM credentials)
↓
Mount in Pod Volume (/mnt/secrets/*)
↓
Application reads from volume
```

## 7. Setup Checklist

### Initialization

- [ ] **Execute Bootstrap Terraform**

  ```bash
  cd infra/terraform/bootstrap && terraform apply
  ```

- [ ] **Set GitHub Secrets**

  ```bash
  .github/scripts/setup-environments.sh
  ```

- [ ] **Configure AWS IAM OIDC Provider**

  - OIDC Provider for `token.actions.githubusercontent.com`
  - Create GitHub Actions Role

- [ ] **Add Dev Environment Secrets**

  - AWS_DEV_ROLE_ARN
  - AWS_ECR_REPOSITORY
  - KUBE_CONFIG_DEV
  - SLACK_WEBHOOK_URL (optional)

- [ ] **Initialize AWS Secrets Manager Secrets**

  ```bash
  cd infra/terraform/envs/dev
  terraform apply
  ```

- [ ] **Install K8s CSI Driver**

  - Create IAM Service Account
  - Deploy Secrets Store CSI Driver
  - Deploy AWS Secrets Store Provider

- [ ] **Deploy SecretProviderClass**
  ```bash
  kubectl apply -f infra/k8s/secrets-provider-classes.yaml
  ```

### Ongoing Operations

- [ ] **Rotate secrets regularly** (every 3-6 months)
- [ ] **Check IAM permissions** (with aws-vault audit)
- [ ] **Terraform state backups** (S3 versioning)
- [ ] **Monitor logs** (CloudWatch, kubectl logs)

## 8. Troubleshooting

### Problem: "OIDC token not accepted"

**Causes:**

- OIDC Provider not configured
- Repository URL not in Trusted Publisher
- Token expired

**Solution:**

```bash
# Check OIDC Provider
aws iam list-open-id-connect-providers

# Check IAM Role Trust Policy
aws iam get-role-policy --role-name github-actions-role
```

### Problem: "CSI Driver mounting failed"

**Causes:**

- Pod has incorrect IAM Service Account
- AWS Secrets Manager secret does not exist
- Secret names do not match

**Solution:**

```bash
# Check CSI Driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver

# Debug SecretProviderClass
kubectl describe secretprovidercla eshop-rds-secrets -n eshop-dev

# Check secret in AWS
aws secretsmanager describe-secret --secret-id eshop-dev/rds/credentials
```

### Problem: "ECR push failed"

**Causes:**

- AWS_ACCOUNT_ID not set
- ECR Repository does not exist
- Credentials expired

**Solution:**

```bash
# List ECR repositories
aws ecr describe-repositories

# Create ECR repository
aws ecr create-repository --repository-name basket-api --region eu-central-1

# Check GitHub Actions Role permissions
aws iam get-role-policy --role-name github-actions-role --policy-name ecr-push-policy
```

## 9. References

- **Files:**

  - `.github/SECRETS_SETUP.md` - Secrets-Dokumentation
  - `.github/environments/dev.json` - Dev Environment Konfiguration
  - `.github/scripts/setup-environments.sh` - Setup-Script
  - `infra/terraform/modules/secrets-manager/` - Secrets Manager Modul
  - `infra/terraform/modules/k8s-csi-driver/` - CSI Driver Modul
  - `infra/terraform/bootstrap/` - State Backend Bootstrap
  - `infra/k8s/secrets-provider-classes.yaml` - K8s Secret Provider Classes

- **External Resources:**
  - [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
  - [Kubernetes Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
  - [AWS Provider for Secrets Store](https://github.com/aws/secrets-store-csi-driver-provider-aws)
  - [GitHub OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
