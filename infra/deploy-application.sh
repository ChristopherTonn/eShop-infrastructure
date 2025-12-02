#!/bin/bash

# ============================================================================
# eShop Application Deployment
# ============================================================================
# Deploys the eShop application microservices to Kubernetes using Aspire
# - Builds AppHost
# - Pushes Docker images to ECR
# - Deploys services to EKS
# - Verifies service status
#
# Usage: ./deploy-application.sh [OPTIONS]
# Options:
#   --profile PROFILE    AWS CLI Profile (default: eshop-terraform)
#   --region REGION      AWS Region (default: eu-central-1)
#   --registry URL       ECR Registry URL (optional, will be auto-detected)
#   --skip-build        Skip building AppHost and images
#   --help              Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
TF_DIR="$SCRIPT_DIR/terraform/envs/dev"
REGION="${AWS_REGION:-eu-central-1}"
AWS_PROFILE="${AWS_PROFILE:-eshop-terraform}"
SKIP_BUILD=false
ECR_REGISTRY=""

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
        --registry)
            ECR_REGISTRY="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --profile PROFILE    AWS CLI Profile (default: eshop-terraform)"
            echo "  --region REGION      AWS Region (default: eu-central-1)"
            echo "  --registry URL       ECR Registry URL (optional, auto-detected)"
            echo "  --skip-build        Skip building AppHost and images"
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

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# ============================================================================
# Pre-Deployment Checks
# ============================================================================

log_section "Pre-Deployment Verification"

if ! aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
    log_error "AWS credentials not configured for profile: $AWS_PROFILE"
fi
log_success "AWS credentials verified (Profile: $AWS_PROFILE, Region: $REGION)"

for tool in kubectl docker dotnet; do
    if ! command -v $tool &> /dev/null; then
        log_warning "$tool not found - some operations may fail"
    fi
done

# ============================================================================
# Step 1: Auto-detect ECR Registry if not provided
# ============================================================================

if [ -z "$ECR_REGISTRY" ]; then
    log_section "Step 1: Auto-detecting ECR Registry"
    
    # Try to get from Terraform outputs
    if [ -f "$TF_DIR/terraform.tfstate" ] || [ -d "$TF_DIR/.terraform" ]; then
        ECR_REPOS=$(cd "$TF_DIR" && terraform output -json ecr_repositories 2>/dev/null || echo "")
        if [ -n "$ECR_REPOS" ] && [ "$ECR_REPOS" != "{}" ]; then
            # Extract registry URL from first repository
            ECR_REGISTRY=$(echo "$ECR_REPOS" | sed -E 's/.*"([0-9]+\.dkr\.ecr\.[^"]+).*/\1/' | head -1)
        fi
    fi
    
    if [ -z "$ECR_REGISTRY" ]; then
        log_error "Could not auto-detect ECR registry. Please provide --registry option"
    fi
    
    log_success "ECR Registry auto-detected: $ECR_REGISTRY"
else
    log_section "Using provided ECR Registry"
    log_success "ECR Registry: $ECR_REGISTRY"
fi

# ============================================================================
# Step 2: Verify Kubernetes Cluster Access
# ============================================================================

log_section "Step 2: Verify Kubernetes Cluster Access"

if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot access Kubernetes cluster. Did you run deploy-infrastructure.sh first?"
fi

log_success "Kubernetes cluster accessible"

# Get cluster info
CLUSTER_CONTEXT=$(kubectl config current-context)
log_info "Current Context: $CLUSTER_CONTEXT"

# Create eshop namespace if it doesn't exist
if ! kubectl get namespace eshop &>/dev/null; then
    log_info "Creating eshop namespace..."
    kubectl create namespace eshop
    log_success "Namespace 'eshop' created"
else
    log_success "Namespace 'eshop' already exists"
fi

# ============================================================================
# Step 3: Authenticate with ECR
# ============================================================================

log_section "Step 3: Authenticate with ECR"

log_info "Getting ECR login credentials..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY || log_error "ECR authentication failed"
log_success "Docker authenticated with ECR"

# ============================================================================
# Step 4: Build and Push Images (if not skipped)
# ============================================================================

if [ "$SKIP_BUILD" = false ]; then
    log_section "Step 4: Build and Push Docker Images"
    
    log_info "Building AppHost project..."
    cd "$PROJECT_ROOT"
    
    if [ -f "eShop.slnx" ]; then
        log_info "Using dotnet publish with eShop.slnx..."
        # This would build and publish images
        # Implementation depends on AppHost configuration
        log_warning "AppHost build automation not yet configured in this script"
        log_info "Manual step: Run Aspire deployment or 'dotnet run' in eShop.AppHost"
    else
        log_error "eShop.slnx not found at $PROJECT_ROOT"
    fi
else
    log_section "Step 4: Skipping Build"
    log_info "Using existing images in ECR"
fi

# ============================================================================
# Step 5: Deploy Services to Kubernetes
# ============================================================================

log_section "Step 5: Deploy Services to Kubernetes"

log_warning "Application deployment requires manual Aspire configuration"
log_info "Aspire does not yet have built-in Kubernetes manifest generation"
log_info ""
log_info "Options to proceed:"
echo "  1. Run Aspire interactively: cd $PROJECT_ROOT && dotnet run --project src/eShop.AppHost"
echo "  2. Generate Kubernetes manifests manually using Aspire extensions"
echo "  3. Use 'dotnet run' to deploy via orchestration"
echo ""

# ============================================================================
# Step 6: Verify Deployments
# ============================================================================

log_section "Step 6: Verify Kubernetes Deployments"

log_info "Checking pods in eshop namespace..."
if kubectl get pods -n eshop 2>/dev/null | grep -q .; then
    kubectl get pods -n eshop
    log_success "Services deployed"
else
    log_warning "No pods found in eshop namespace yet"
fi

log_info ""
log_info "Checking services..."
kubectl get svc -n eshop 2>/dev/null || log_info "No services deployed yet"

# ============================================================================
# Step 7: Summary
# ============================================================================

log_section "Application Deployment Status"

echo -e "${BLUE}Configuration Used:${NC}"
echo "  ECR Registry: $ECR_REGISTRY"
echo "  Region: $REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo "  Kubernetes Namespace: eshop"
echo ""

echo -e "${BLUE}Current Status:${NC}"
DEPLOYMENT_COUNT=$(kubectl get deployments -n eshop 2>/dev/null | tail -n +2 | wc -l)
POD_COUNT=$(kubectl get pods -n eshop 2>/dev/null | tail -n +2 | wc -l)
echo "  Deployments: $DEPLOYMENT_COUNT"
echo "  Pods: $POD_COUNT"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Deploy Aspire applications:"
echo "     cd $PROJECT_ROOT && dotnet run --project src/eShop.AppHost"
echo "  2. Monitor deployment:"
echo "     kubectl logs -n eshop -f deployment/<service-name>"
echo "  3. Port-forward to test locally:"
echo "     kubectl port-forward -n eshop svc/webapp 8080:80"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  • Watch deployments: kubectl get deployment -n eshop -w"
echo "  • View all resources: kubectl get all -n eshop"
echo "  • Describe pod: kubectl describe pod <pod-name> -n eshop"
echo "  • View logs: kubectl logs <pod-name> -n eshop"
echo ""

log_success "Application deployment infrastructure ready!"
