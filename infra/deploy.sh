#!/bin/bash

# ============================================================================
# eShop Deployment Orchestrator
# ============================================================================
# Main orchestrator for eShop deployment
# Handles infrastructure and application deployment with clear separation of concerns
#
# Infrastructure: Deploy AWS resources via Terraform (DevOps responsibility)
# Application:   Deploy eShop services via Aspire (Developer responsibility)
#
# Usage: ./deploy.sh [COMMAND] [OPTIONS]
# Commands:
#   infrastructure    Deploy infrastructure only (Terraform)
#   application       Deploy application only (Aspire)
#   all              Deploy everything (infrastructure then application)
#   help             Show this help message
#
# Options:
#   --profile PROFILE    AWS CLI Profile (default: eshop-terraform)
#   --region REGION      AWS Region (default: eu-central-1)
#   --skip-build        Skip application build step
#   --help              Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-eu-central-1}"
AWS_PROFILE="${AWS_PROFILE:-eshop-terraform}"
SKIP_BUILD=false

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
    echo -e "${YELLOW}$1${NC}"
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

show_help() {
    cat << EOF

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  infrastructure    Deploy infrastructure only (Terraform → VPC, EKS, RDS, ECR, etc)
  application       Deploy application only (Aspire → Kubernetes services)
  all              Deploy both infrastructure and application sequentially
  help             Show this help message

Options:
  --profile PROFILE    AWS CLI Profile (default: eshop-terraform)
  --region REGION      AWS Region (default: eu-central-1)
  --skip-build        Skip application build step
  --help              Show this help message

Examples:
  ./deploy.sh infrastructure --profile eshop-terraform
  ./deploy.sh application --region eu-central-1
  ./deploy.sh all
  ./deploy.sh infrastructure --help
  
For more information on each command, use:
  ./deploy.sh infrastructure --help
  ./deploy.sh application --help

EOF
}

# Parse global options
COMMAND=""
REMAINING_ARGS=()

for arg in "$@"; do
    if [ -z "$COMMAND" ] && [[ ! "$arg" =~ ^-- ]]; then
        COMMAND="$arg"
    else
        REMAINING_ARGS+=("$arg")
    fi
done

# Extract options from remaining args
while [[ ${#REMAINING_ARGS[@]} -gt 0 ]]; do
    case "${REMAINING_ARGS[0]}" in
        --profile)
            AWS_PROFILE="${REMAINING_ARGS[1]}"
            REMAINING_ARGS=("${REMAINING_ARGS[@]:2}")
            ;;
        --region)
            REGION="${REMAINING_ARGS[1]}"
            REMAINING_ARGS=("${REMAINING_ARGS[@]:2}")
            ;;
        --skip-build)
            SKIP_BUILD=true
            REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: ${REMAINING_ARGS[0]}"
            ;;
    esac
done

# Validate command
case "${COMMAND:-help}" in
    infrastructure|application|all)
        # Valid command
        ;;
    help|"")
        show_help
        exit 0
        ;;
    *)
        log_error "Unknown command: $COMMAND\n\nUse '$0 help' for usage information"
        ;;
esac

# Export for subscripts
export AWS_PROFILE
export AWS_REGION="$REGION"

log_section "eShop Deployment Orchestrator"
log_info "Command: ${COMMAND}"
log_info "Profile: ${AWS_PROFILE}"
log_info "Region: ${REGION}"
echo ""

# ============================================================================
# Deploy Infrastructure
# ============================================================================

deploy_infrastructure() {
    log_section "Deploying Infrastructure"
    
    if [ ! -f "$SCRIPT_DIR/deploy-infrastructure.sh" ]; then
        log_error "deploy-infrastructure.sh not found at $SCRIPT_DIR"
    fi
    
    bash "$SCRIPT_DIR/deploy-infrastructure.sh" --profile "$AWS_PROFILE" --region "$REGION"
}

# ============================================================================
# Deploy Application
# ============================================================================

deploy_application() {
    log_section "Deploying Application"
    
    if [ ! -f "$SCRIPT_DIR/deploy-application.sh" ]; then
        log_error "deploy-application.sh not found at $SCRIPT_DIR"
    fi
    
    BUILD_ARGS=""
    if [ "$SKIP_BUILD" = true ]; then
        BUILD_ARGS="--skip-build"
    fi
    
    bash "$SCRIPT_DIR/deploy-application.sh" --profile "$AWS_PROFILE" --region "$REGION" $BUILD_ARGS
}

# ============================================================================
# Execute Based on Command
# ============================================================================

case "$COMMAND" in
    infrastructure)
        deploy_infrastructure
        ;;
    application)
        deploy_application
        ;;
    all)
        deploy_infrastructure
        echo ""
        read -p "Infrastructure deployment complete. Press Enter to continue with application deployment..."
        deploy_application
        ;;
esac

log_section "Orchestrator Complete ✅"
log_info "Next steps depend on your deployment choice."
echo ""
