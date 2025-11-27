#!/bin/bash

# ============================================================================
# eShop Infrastructure Deployment
# ============================================================================
# Deploys AWS infrastructure via Terraform
# - VPC, Subnets, NAT Gateways
# - EKS Cluster
# - RDS PostgreSQL
# - ElastiCache Redis
# - ECR Repositories
# - Secrets Manager
# - IAM Roles & Policies
#
# Usage: ./deploy-infrastructure.sh [OPTIONS]
# Options:
#   --profile PROFILE    AWS CLI Profile (default: eshop-terraform)
#   --region REGION      AWS Region (default: eu-central-1)
#   --help              Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/envs/dev"
REGION="${AWS_REGION:-eu-central-1}"
AWS_PROFILE="${AWS_PROFILE:-eshop-terraform}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --profile PROFILE    AWS CLI Profile (default: eshop-terraform)"
            echo "  --region REGION      AWS Region (default: eu-central-1)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Export profile for all AWS CLI calls
export AWS_PROFILE

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper Functions
log_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============================================================================
# Pre-Deployment Checks
# ============================================================================

log_section "Pre-Deployment Verification"

if ! aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
    log_error "AWS credentials not configured for profile: $AWS_PROFILE"
fi
log_success "AWS credentials verified (Profile: $AWS_PROFILE, Region: $REGION)"

for tool in terraform aws kubectl; do
    if ! command -v $tool &> /dev/null; then
        log_error "$tool not installed"
    fi
done
log_success "All required tools installed"

# ============================================================================
# Step 1a: Terraform Infrastructure Deployment
# ============================================================================

log_section "Step 1a: Terraform Infrastructure Deployment"

cd "$TF_DIR"

log_info "Initializing Terraform..."
terraform init -upgrade

log_info "Validating Terraform configuration..."
terraform validate || log_error "Terraform validation failed"

log_info "Creating Terraform plan..."
terraform plan -out=tfplan -compact-warnings

echo ""
read -p "🔄 Ready to apply infrastructure? Press Enter to continue..."

log_info "Applying Terraform plan..."
terraform apply tfplan || log_error "Terraform apply failed"

log_success "Infrastructure deployed"

# ============================================================================
# Step 1b: Wait for EKS Cluster to be Ready
# ============================================================================

log_section "Step 1b: Waiting for EKS Cluster to be Ready"

CLUSTER_NAME=$(cd "$TF_DIR" && terraform output -raw eks_cluster_name 2>/dev/null)
if [ -z "$CLUSTER_NAME" ]; then
    log_error "Failed to get EKS cluster name from Terraform"
fi

log_info "⏳ Waiting for EKS cluster to reach ACTIVE state (this takes 2-3 minutes)..."

CLUSTER_STATUS=""
MAX_RETRIES=60
RETRY_COUNT=0

while [ "$CLUSTER_STATUS" != "ACTIVE" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo "")
    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        log_success "EKS Cluster is ACTIVE ✅"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    PERCENT=$((RETRY_COUNT * 100 / MAX_RETRIES))
    echo -ne "  Status: $CLUSTER_STATUS | Progress: $PERCENT% ($RETRY_COUNT/$MAX_RETRIES)\r"
    sleep 5
done

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    log_error "EKS Cluster failed to reach ACTIVE state within timeout"
fi

log_success "EKS Cluster ready for Kubernetes operations"

# ============================================================================
# Step 2: Configure kubectl & Get ECR Registry
# ============================================================================

log_section "Step 2: Configure kubectl & Get ECR Registry"

log_info "Configuring kubectl for cluster access..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
log_success "kubectl configured for $CLUSTER_NAME"

# Get ECR registry URL from Terraform outputs
ECR_REPOS=$(cd "$TF_DIR" && terraform output -json ecr_repositories 2>/dev/null)
if [ -z "$ECR_REPOS" ] || [ "$ECR_REPOS" = "{}" ]; then
    log_error "Failed to get ECR repositories from Terraform"
fi

# Extract the registry URL from one of the repository URLs
# Format: 333917886778.dkr.ecr.eu-central-1.amazonaws.com/eshop-dev-service
ECR_REGISTRY=$(echo "$ECR_REPOS" | sed 's/.*"\([0-9]*\.dkr\.ecr\.[^"]*\).*/\1/' | head -1)

if [ -z "$ECR_REGISTRY" ] || [[ "$ECR_REGISTRY" == *"sed"* ]] || [[ "$ECR_REGISTRY" == *"{"* ]]; then
    log_error "Could not extract ECR registry from: $ECR_REPOS"
fi

log_success "ECR Registry: $ECR_REGISTRY"

# ============================================================================
# Step 3: Verify Infrastructure
# ============================================================================

log_section "Step 3: Verify Infrastructure"

log_info "Cluster Status:"
kubectl cluster-info

log_info ""
log_info "Node Status:"
kubectl get nodes

log_info ""
log_info "Namespace Status:"
kubectl get namespace eshop 2>/dev/null || log_info "eshop namespace not yet created (will be created by application deployment)"

# ============================================================================
# Step 4: Summary
# ============================================================================

log_section "Infrastructure Deployment Complete! ✅"

echo -e "${GREEN}✅ AWS Infrastructure Ready${NC}"
echo ""
echo -e "${BLUE}Infrastructure Details:${NC}"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo "  ECR Registry: $ECR_REGISTRY"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Deploy application: ./deploy.sh application"
echo "  2. Or deploy everything: ./deploy.sh all"
echo ""
echo -e "${BLUE}Manual Commands:${NC}"
echo "  • Check cluster: kubectl cluster-info"
echo "  • List nodes: kubectl get nodes"
echo "  • View ECR repos: aws ecr describe-repositories --region $REGION"
echo ""

log_success "Infrastructure is ready for application deployment!"
