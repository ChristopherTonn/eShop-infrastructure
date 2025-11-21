#!/bin/bash
# GitHub Environment Configuration Script
# This script creates GitHub Environments with variables and secrets

set -e

REPO_OWNER="ChristopherTonn"
REPO_NAME="eShop"
GH_API="https://api.github.com"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}GitHub Environment Setup${NC}"
echo "======================================="

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI (gh) not found. Please install it.${NC}"
    exit 1
fi

# Configuration for Dev Environment
echo -e "${BLUE}Configuring Dev Environment...${NC}"

# Environment variables for dev
declare -A DEV_VARS=(
    ["AWS_REGION"]="eu-central-1"
    ["ENVIRONMENT"]="dev"
    ["ECR_REGISTRY_PREFIX"]="dev"
    ["KUBERNETES_NAMESPACE"]="dev"
    ["KUBERNETES_CLUSTER_NAME"]="eshop-dev-eks"
    ["TERRAFORM_BACKEND"]="s3"
    ["TERRAFORM_BACKEND_BUCKET"]="eshop-tf-state-dev"
    ["TERRAFORM_LOCK_TABLE"]="eshop-tf-locks-dev"
    ["TERRAFORM_WORKSPACE"]="dev"
    ["DEPLOY_TIMEOUT"]="600"
)

# Secrets that must be maintained (not set here, only listed)
DEV_SECRETS=(
    "AWS_DEV_ROLE_ARN"
    "AWS_ECR_REPOSITORY"
    "KUBE_CONFIG_DEV"
    "SLACK_WEBHOOK_URL"
)

echo -e "${GREEN}Environment Variables for dev:${NC}"
for key in "${!DEV_VARS[@]}"; do
    echo "  $key = ${DEV_VARS[$key]}"
    # Set variable in GitHub Environment
    gh variable set "$key" --env dev --body "${DEV_VARS[$key]}" 2>/dev/null || echo "    Skipped (already exists)"
done

echo -e "\n${GREEN}Required Secrets for dev:${NC}"
for secret in "${DEV_SECRETS[@]}"; do
    echo "  ⚠️  $secret (MANUALLY ENTER)"
done

echo -e "\n${BLUE}Setup completed!${NC}"
echo "======================================="
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Go to: https://github.com/$REPO_OWNER/$REPO_NAME/settings/environments/dev"
echo "2. Add the following secrets:"
for secret in "${DEV_SECRETS[@]}"; do
    echo "   - $secret"
done
echo ""
echo "3. Optional: Set Deployment Branch Policy"
echo "   - Only 'develop' branch allowed for deployments"
