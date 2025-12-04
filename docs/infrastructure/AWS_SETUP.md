# 🔐 AWS Account Setup & Configuration

Prerequisites and initial setup for deploying eShop to AWS.

**Navigation:** [← Terraform](TERRAFORM_GUIDE.md) | [Up ↑](../INDEX.md) | [Related: Kubernetes →](../deployment/KUBERNETES_DEPLOYMENT.md)

## 📋 AWS Prerequisites

### Create AWS Account

1. Go to [AWS Console](https://console.aws.amazon.com)
2. Click "Create AWS Account"
3. Enter email, password, account name
4. Add payment method
5. Verify account via SMS or email
6. Select **"Basic support plan"** (free tier eligible)

### Enable Services

In AWS Console:

- ✅ EC2 (Elastic Compute Cloud)
- ✅ ECS (Elastic Container Service)
- ✅ EKS (Elastic Kubernetes Service)
- ✅ RDS (Relational Database Service)
- ✅ ElastiCache (Redis/Memcached)
- ✅ VPC (Virtual Private Cloud)
- ✅ ECR (Elastic Container Registry)
- ✅ IAM (Identity & Access Management)
- ✅ Secrets Manager
- ✅ CloudWatch (Monitoring & Logs)

---

## 👤 Create IAM User

### Step 1: Create User

```bash
# Using AWS CLI
aws iam create-user --user-name eshop-deployment
```

Or via AWS Console:

1. Navigate to **IAM** → **Users**
2. Click **Create user**
3. Name: `eshop-deployment`
4. Click **Create**

### Step 2: Attach Policies

```bash
# Attach necessary policies
aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFullAccess

aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess

aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonECRFullAccess

aws iam attach-user-policy \
  --user-name eshop-deployment \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### Step 3: Create Access Keys

```bash
# Generate access key ID and secret
aws iam create-access-key --user-name eshop-deployment

# Output:
# {
#   "AccessKey": {
#     "UserName": "eshop-deployment",
#     "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
#     "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#   }
# }
```

---

## 🔑 Configure AWS CLI

### Option A: Interactive Setup

```bash
aws configure

# Enter:
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region: eu-central-1
# Default output format: json
```

### Option B: Manual Configuration

```bash
# Create ~/.aws/credentials file
mkdir -p ~/.aws

cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[eshop]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

# Create ~/.aws/config file
cat > ~/.aws/config << EOF
[default]
region = eu-central-1
output = json

[profile eshop]
region = eu-central-1
output = json
EOF

# Fix permissions
chmod 600 ~/.aws/credentials ~/.aws/config
```

### Step 4: Verify Configuration

```bash
# Test AWS CLI
aws sts get-caller-identity

# Expected output:
# {
#   "UserId": "AIDAI23HXD2O7EXAMPLE",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/eshop-deployment"
# }
```

---

## 🔗 GitHub Actions OIDC (Recommended)

### Step 1: Create OIDC Provider in AWS

```bash
# Get GitHub's OIDC provider certificate
GITHUB_OIDC_CERT=$(curl -s https://token.actions.githubusercontent.com/.well-known/openid-configuration | jq -r '.signing_certs_url')

# Create OIDC provider in AWS IAM
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 1c58a3e8518e8759bf075b76b750d4f2c0f8d3a7
```

Or via Console:

1. Navigate to **IAM** → **Identity Providers**
2. Click **Create provider**
3. Select **OpenID Connect**
4. Provider URL: `https://token.actions.githubusercontent.com`
5. Audience: `sts.amazonaws.com`
6. Click **Add provider**

### Step 2: Create IAM Role for GitHub Actions

```bash
# Create trust policy
cat > trust-policy.json << 'EOF'
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:dotnet-architecture/eShop:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-eshop \
  --assume-role-policy-document file://trust-policy.json

# Attach deployment policy
aws iam attach-role-policy \
  --role-name github-actions-eshop \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### Step 3: Configure GitHub Actions

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write # Required for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-eshop
          aws-region: eu-central-1

      - name: Deploy infrastructure
        run: |
          cd infra/terraform/envs/dev
          terraform init
          terraform apply -auto-approve
```

---

## 🗝️ SSH Key Setup

### Create EC2 Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name eshop-dev-key \
  --region eu-central-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/eshop-dev-key.pem

# Set permissions
chmod 600 ~/.ssh/eshop-dev-key.pem

# Verify key exists
ls -la ~/.ssh/eshop-dev-key.pem
```

### Configure SSH Config

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << EOF

Host eshop-eks
  HostName EC2_PUBLIC_IP
  User ec2-user
  IdentityFile ~/.ssh/eshop-dev-key.pem
  StrictHostKeyChecking no
EOF

# Test connection
ssh eshop-eks "docker --version"
```

---

## 📊 Cost Estimation

### Development Environment (Typical Costs)

| Resource          | Instance       | Monthly Cost    |
| ----------------- | -------------- | --------------- |
| EKS Control Plane | —              | $73.00          |
| EKS Worker Nodes  | 2x t3.medium   | $58.32          |
| RDS PostgreSQL    | db.t3.micro    | $37.44          |
| ElastiCache Redis | cache.t3.micro | $45.44          |
| NAT Gateway       | 1x             | $32.40          |
| **Total**         | —              | **~$247/month** |

### Cost Optimization Tips

1. **Use Spot Instances** for non-critical workloads (-70% cost)
2. **Stop resources** when not in use
3. **Use smaller instances** (t3.micro for dev)
4. **Consolidate services** on fewer nodes
5. **Enable auto-scaling** to avoid overprovisioning

### Monitor Costs

```bash
# View cost and usage
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost"

# Set up billing alerts
aws cloudwatch put-metric-alarm \
  --alarm-name eshop-monthly-billing \
  --alarm-description "Alert when monthly bill exceeds $300" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold
```

---

## 🔒 Security Best Practices

### Enable MFA

```bash
# Create virtual MFA device
aws iam enable-mfa-device \
  --user-name eshop-deployment \
  --serial-number arn:aws:iam::123456789012:mfa/eshop-deployment \
  --authentication-code1 123456 \
  --authentication-code2 654321
```

### Rotate Access Keys

```bash
# Create new access key
aws iam create-access-key --user-name eshop-deployment

# Deactivate old key
aws iam update-access-key \
  --user-name eshop-deployment \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive

# Delete old key after verification
aws iam delete-access-key \
  --user-name eshop-deployment \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

### Enable CloudTrail

```bash
# Enable logging of all AWS API calls
aws cloudtrail create-trail \
  --name eshop-trail \
  --s3-bucket-name eshop-cloudtrail-logs

aws cloudtrail start-logging --trail-name eshop-trail
```

### Enable VPC Flow Logs

```bash
# Log network traffic
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-12345678 \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/eshop-flow-logs
```

---

## 🚨 Cleanup

### Delete AWS Resources

```bash
# ⚠️ WARNING: This deletes all resources!

# Delete Terraform stack
cd infra/terraform/envs/dev
terraform destroy

# Or manually:
# 1. ECS clusters
# 2. RDS instances
# 3. ElastiCache clusters
# 4. NAT Gateways
# 5. VPC
# 6. IAM roles
# 7. OIDC providers
```

---

## 📚 Related Documentation

- [Terraform Guide](TERRAFORM_GUIDE.md)
- [Kubernetes Deployment](../deployment/KUBERNETES_DEPLOYMENT.md)
- [Infrastructure Overview](README.md)

---

**Last updated:** December 2025
