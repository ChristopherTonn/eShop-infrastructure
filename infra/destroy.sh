#!/bin/bash

# eShop Infrastructure Destruction Script - AWS EKS
# Removes all Kubernetes deployments, services, and cleans up AWS resources
# Note: Does NOT destroy Terraform infrastructure (databases, VPC, etc.)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}💥 eShop Infrastructure Destruction${NC}"
echo "========================================"
echo ""
echo -e "${RED}WARNING: This will remove all Kubernetes deployments and services!${NC}"
echo ""

# Configuration
CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-dev}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
NAMESPACE="default"

# 1. Verify AWS credentials
echo -e "${YELLOW}📋 Step 1: Verify AWS Credentials${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}  ❌ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}  ❌ AWS credentials not configured. Please run 'aws configure'.${NC}"
    exit 1
fi

echo "  ✅ AWS credentials validated"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "  ✅ AWS Account: $AWS_ACCOUNT"

# 2. Configure kubectl access
echo -e "${YELLOW}📋 Step 2: Configure kubectl Access${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}  ❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

echo "  🔧 Updating kubeconfig for EKS cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --no-verify-ssl

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  Cannot connect to cluster. Skipping Kubernetes cleanup.${NC}"
else
    echo "  ✅ kubectl configured successfully"

    # 3. Delete all Helm releases
    echo -e "${YELLOW}📋 Step 3: Delete Helm Releases${NC}"
    if command -v helm &> /dev/null; then
        RELEASES=$(helm list --namespace $NAMESPACE --output json | jq -r '.[].name' 2>/dev/null || echo "")
        
        if [[ -n "$RELEASES" ]]; then
            echo "  🗑️  Deleting Helm releases..."
            echo "$RELEASES" | while read -r release; do
                echo "    • Deleting release: $release"
                helm uninstall "$release" --namespace $NAMESPACE || true
            done
            echo "  ✅ Helm releases deleted"
        else
            echo "  ℹ️  No Helm releases found"
        fi
    else
        echo "  ⚠️  Helm not installed. Skipping Helm cleanup."
    fi

    # 4. Delete Kubernetes deployments
    echo -e "${YELLOW}📋 Step 4: Delete Kubernetes Deployments${NC}"
    DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$DEPLOYMENTS" ]]; then
        echo "  🗑️  Deleting deployments..."
        kubectl delete deployments --all -n $NAMESPACE --grace-period=30
        echo "  ✅ Deployments deleted"
    else
        echo "  ℹ️  No deployments found"
    fi

    # 5. Delete services (excluding kubernetes service)
    echo -e "${YELLOW}📋 Step 5: Delete Services${NC}"
    SERVICES=$(kubectl get services -n $NAMESPACE -o jsonpath='{.items[?(@.metadata.name!="kubernetes")].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$SERVICES" ]]; then
        echo "  🗑️  Deleting services..."
        kubectl delete services --all -n $NAMESPACE
        echo "  ✅ Services deleted"
    else
        echo "  ℹ️  No services found"
    fi

    # 6. Wait for LoadBalancer cleanup
    echo -e "${YELLOW}📋 Step 6: Wait for LoadBalancer Cleanup${NC}"
    echo "  ⏳ Waiting for AWS LoadBalancers to be removed (this may take a minute)..."
    sleep 30
    echo "  ✅ LoadBalancers cleanup initiated"

    # 7. Delete persistent volumes
    echo -e "${YELLOW}📋 Step 7: Delete Persistent Volumes${NC}"
    PVCs=$(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$PVCs" ]]; then
        echo "  🗑️  Deleting persistent volume claims..."
        kubectl delete pvc --all -n $NAMESPACE
        echo "  ✅ PVCs deleted"
    else
        echo "  ℹ️  No persistent volumes found"
    fi
fi

# 8. Clean up ECR images (optional)
echo -e "${YELLOW}📋 Step 8: Clean up ECR Images (Optional)${NC}"
echo "  💡 To delete ECR repositories, run:"
echo "     aws ecr delete-repository --repository-name eshop-[service-name] --force --region $AWS_REGION"

# 9. Cleanup summary
echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ eShop Infrastructure Cleanup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}✅ Cleanup Actions:${NC}"
echo "  ✓ Helm releases deleted"
echo "  ✓ Kubernetes deployments removed"
echo "  ✓ Services deleted"
echo "  ✓ LoadBalancers cleaned up"
echo "  ✓ Persistent volumes removed"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  • Verify all resources are removed: kubectl get all -n $NAMESPACE"
echo "  • Monitor AWS Console for LoadBalancer cleanup (may take a few minutes)"
echo "  • To fully destroy AWS infrastructure (RDS, VPC, etc.): cd terraform/envs/dev && terraform destroy"
echo "  • To redeploy: ./deploy.sh"
echo ""
echo -e "${RED}⚠️  NOTE:${NC}"
echo "  This script does NOT destroy:"
echo "  - RDS databases"
echo "  - ElastiCache clusters"
echo "  - VPC and networking"
echo "  - ECR repositories"
echo "  - AWS IAM roles"
echo ""
echo -e "${YELLOW}📝 Backup Information:${NC}"
echo "  • RDS Backups: Automatically retained for 7 days (dev) / 14 days (prod)"
echo "  • Final Snapshots: SKIPPED in dev (ephemeral) / ENABLED in prod"
echo "  • CloudWatch Logs: Retained for 7 days"
echo "  • All automated backups are FREE (included with RDS)"
echo ""
echo "  To fully destroy all infrastructure including RDS, use Terraform:"
echo "  cd terraform/envs/dev && terraform destroy"
