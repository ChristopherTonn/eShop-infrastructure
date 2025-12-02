#!/bin/bash
# eShop Quick Deployment Reference
# =================================
# Copy & paste these commands to deploy infrastructure

# Step 1: Setup (only once)
bash /Users/christophertonn/Documents/WORKSPACE/eShop/infra/setup-ssh-key.sh

# Step 2: Navigate to dev environment
cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev

# Step 3: Initialize Terraform (only if needed)
terraform init -upgrade

# Step 4: Validate configuration
terraform validate

# Step 5: Create plan
terraform plan -out=tfplan

# Step 6: Review plan output carefully!
# Step 7: Apply infrastructure
terraform apply tfplan

# Step 8: Get outputs
terraform output

# Step 9: Configure kubectl
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null)
AWS_REGION="eu-central-1"

aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Step 10: Verify cluster
kubectl cluster-info
kubectl get nodes

# Step 11: ECR Login
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com

# Step 12: List ECR repositories
aws ecr describe-repositories --region eu-central-1 --output table


# ==============================================================================
# CLEANUP (when done)
# ==============================================================================

# Option 1: Terraform destroy
# cd /Users/christophertonn/Documents/WORKSPACE/eShop/infra/terraform/envs/dev
# terraform destroy

# Option 2: Complete cleanup script
# bash /Users/christophertonn/Documents/WORKSPACE/eShop/infra/cleanup-aws.sh
