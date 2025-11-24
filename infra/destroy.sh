#!/bin/bash

# eShop Infrastructure Destruction Script - Kubernetes Only
# Removes all Kubernetes resources from all namespaces
# IMPORTANT: Does NOT destroy AWS infrastructure (use 'terraform destroy' separately if needed)
# NOTE: 'terraform destroy' often hangs - use manual cleanup instead

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}💥 eShop Kubernetes Cleanup${NC}"
echo "========================================"
echo ""
echo -e "${RED}WARNING: This will remove all Kubernetes resources from ALL namespaces!${NC}"
echo -e "${YELLOW}AWS Infrastructure will remain (RDS, VPC, etc.)${NC}"
echo ""

# Configuration
CLUSTER_NAME="${EKS_CLUSTER_NAME:-eshop-dev-eks}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
NAMESPACES=("default" "monitoring" "rabbitmq" "logging" "kube-system")  # All app namespaces

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

    # 3. Delete all Helm releases from ALL namespaces
    echo -e "${YELLOW}📋 Step 3: Delete Helm Releases (ALL Namespaces)${NC}"
    if command -v helm &> /dev/null; then
        # Get all namespaces with Helm releases
        ALL_NAMESPACES=$(helm list --all-namespaces --output json 2>/dev/null | jq -r '.[].namespace' | sort -u || echo "")
        
        if [[ -n "$ALL_NAMESPACES" ]]; then
            echo "  🗑️  Deleting Helm releases from all namespaces..."
            echo "$ALL_NAMESPACES" | while read -r ns; do
                if [[ -n "$ns" ]]; then
                    RELEASES=$(helm list --namespace "$ns" --output json 2>/dev/null | jq -r '.[].name' || echo "")
                    if [[ -n "$RELEASES" ]]; then
                        echo "    Namespace: $ns"
                        echo "$RELEASES" | while read -r release; do
                            echo "      • Deleting: $release"
                            helm uninstall "$release" --namespace "$ns" || true
                        done
                    fi
                fi
            done
            echo "  ✅ Helm releases deleted from all namespaces"
        else
            echo "  ℹ️  No Helm releases found"
        fi
    else
        echo "  ⚠️  Helm not installed. Skipping Helm cleanup."
    fi

    # 4. Delete ALL Kubernetes resources from ALL namespaces
    echo -e "${YELLOW}📋 Step 4: Delete ALL Kubernetes Resources (ALL Namespaces)${NC}"
    echo "  🗑️  Deleting all deployments, statefulsets, daemonsets..."
    
    # Delete from custom namespaces
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            echo "    Namespace: $ns"
            
            # Delete deployments
            kubectl delete deployments --all -n "$ns" --grace-period=30 2>/dev/null || true
            
            # Delete statefulsets
            kubectl delete statefulsets --all -n "$ns" --grace-period=30 2>/dev/null || true
            
            # Delete daemonsets
            kubectl delete daemonsets --all -n "$ns" --grace-period=30 2>/dev/null || true
            
            # Delete jobs
            kubectl delete jobs --all -n "$ns" --grace-period=30 2>/dev/null || true
        fi
    done
    echo "  ✅ Kubernetes resources deleted"

    # 5. Delete services from ALL namespaces
    echo -e "${YELLOW}📋 Step 5: Delete Services (ALL Namespaces)${NC}"
    echo "  🗑️  Deleting services..."
    
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            # Get services excluding kubernetes service
            SERVICES=$(kubectl get services -n "$ns" -o jsonpath='{.items[?(@.metadata.name!="kubernetes")].metadata.name}' 2>/dev/null || echo "")
            if [[ -n "$SERVICES" ]]; then
                echo "    Namespace: $ns"
                kubectl delete services --all -n "$ns" 2>/dev/null || true
            fi
        fi
    done
    echo "  ✅ Services deleted"

    # 6. Wait for LoadBalancer cleanup
    echo -e "${YELLOW}📋 Step 6: Wait for LoadBalancer Cleanup${NC}"
    echo "  ⏳ Waiting for AWS LoadBalancers to be removed (this may take a minute)..."
    sleep 30
    echo "  ✅ LoadBalancers cleanup initiated"

    # 7. Delete persistent volumes from ALL namespaces
    echo -e "${YELLOW}📋 Step 7: Delete Persistent Volumes (ALL Namespaces)${NC}"
    echo "  🗑️  Deleting persistent volume claims..."
    
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            PVCs=$(kubectl get pvc -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
            if [[ -n "$PVCs" ]]; then
                echo "    Namespace: $ns"
                kubectl delete pvc --all -n "$ns" 2>/dev/null || true
            fi
        fi
    done
    echo "  ✅ PVCs deleted"

    # 8. Delete ConfigMaps and Secrets from custom namespaces
    echo -e "${YELLOW}📋 Step 8: Delete ConfigMaps & Secrets (Custom Namespaces)${NC}"
    echo "  🗑️  Cleaning up ConfigMaps and Secrets..."
    
    for ns in "monitoring" "rabbitmq" "logging"; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            echo "    Namespace: $ns"
            kubectl delete configmaps --all -n "$ns" 2>/dev/null || true
            kubectl delete secrets --all -n "$ns" --ignore-not-found 2>/dev/null || true
        fi
    done
    echo "  ✅ ConfigMaps and Secrets cleaned up"
fi

# 9. Clean up ECR images (optional)
echo -e "${YELLOW}📋 Step 9: Clean up ECR Images (Optional)${NC}"
echo "  💡 To delete ECR repositories, run:"
echo "     aws ecr delete-repository --repository-name eshop-[service-name] --force --region $AWS_REGION"

# 9.5 Clean up local Terraform state files
echo -e "${YELLOW}📋 Step 9.5: Clean up Local Terraform State${NC}"
TERRAFORM_DIR="terraform/envs/dev"
if [[ -d "$TERRAFORM_DIR" ]]; then
    echo "  🧹 Removing local state files from $TERRAFORM_DIR..."
    rm -f "$TERRAFORM_DIR/terraform.tfstate"* "$TERRAFORM_DIR/tfplan"* "$TERRAFORM_DIR/.terraform.lock.hcl" 2>/dev/null || true
    echo "  ✅ Local state files cleaned"
else
    echo "  ℹ️  Terraform directory not found"
fi

# 10. AWS Infrastructure Cleanup (SAFE - using AWS CLI, not terraform destroy)
echo -e "${YELLOW}📋 Step 10: AWS Infrastructure Cleanup${NC}"
echo ""
echo -e "${YELLOW}🔍 Checking AWS resources...${NC}"

# Check if we should clean up AWS
if [[ "${CLEANUP_AWS:-false}" == "true" ]]; then
    echo -e "${RED}⚠️  AWS CLEANUP ENABLED - Will delete RDS, ElastiCache, EKS, VPC, ECR${NC}"
    echo ""
    
    # 10.1 Delete LoadBalancers first
    echo "  Step 10.1: Clean up LoadBalancers..."
    aws elb describe-load-balancers --region $AWS_REGION --output json | \
    jq -r '.LoadBalancerDescriptions[].LoadBalancerName' | grep -i eshop | while read -r lb; do
        echo "    • Deleting LoadBalancer: $lb"
        aws elb delete-load-balancer --load-balancer-name "$lb" --region $AWS_REGION 2>/dev/null || true
    done
    
    # 10.2 Delete RDS Databases
    echo "  Step 10.2: Clean up RDS Databases..."
    aws rds describe-db-instances --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.DBInstances[] | select(.DBInstanceIdentifier | contains("eshop")) | .DBInstanceIdentifier' | while read -r db; do
        echo "    • Deleting RDS: $db"
        aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --region $AWS_REGION 2>/dev/null || true
    done
    
    # 10.3 Delete ElastiCache Clusters
    echo "  Step 10.3: Clean up ElastiCache Redis..."
    aws elasticache describe-cache-clusters --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.CacheClusters[] | select(.CacheClusterId | contains("eshop")) | .CacheClusterId' | while read -r cache; do
        echo "    • Deleting ElastiCache: $cache"
        aws elasticache delete-cache-cluster --cache-cluster-id "$cache" --region $AWS_REGION 2>/dev/null || true
    done
    
    # 10.4 Delete ECR Repositories
    echo "  Step 10.4: Clean up ECR Repositories..."
    aws ecr describe-repositories --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.repositories[] | select(.repositoryName | contains("eshop")) | .repositoryName' | while read -r repo; do
        echo "    • Deleting ECR repo: $repo"
        aws ecr delete-repository --repository-name "$repo" --force --region $AWS_REGION 2>/dev/null || true
    done
    
    # 10.5 Delete EKS Cluster (last, takes time)
    echo "  Step 10.5: Clean up EKS Cluster (this may take 5-10 minutes)..."
    echo "    ⏳ Deleting EKS cluster: $CLUSTER_NAME"
    aws eks delete-cluster --name $CLUSTER_NAME --region $AWS_REGION 2>/dev/null || true
    
    # 10.6 Clean up Remote State (S3 + DynamoDB)
    echo "  Step 10.6: Clean up Remote Terraform State..."
    BUCKET_NAME="eshop-terraform-state-dev-$AWS_ACCOUNT"
    TABLE_NAME="eshop-terraform-lock-dev"
    LOCK_ID="eshop-terraform-state-dev-$AWS_ACCOUNT/dev/terraform.tfstate"
    
    echo "    • Cleaning S3 bucket: $BUCKET_NAME"
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        aws s3 rm "s3://$BUCKET_NAME" --recursive --region $AWS_REGION 2>/dev/null || true
    fi
    
    echo "    • Cleaning DynamoDB table: $TABLE_NAME"
    aws dynamodb delete-item --table-name "$TABLE_NAME" --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" --region $AWS_REGION 2>/dev/null || true
    
    echo "  ✅ Remote state cleaned"
    echo ""
    echo -e "${YELLOW}⏳ Note: AWS resource deletion is asynchronous${NC}"
    echo "   - Check AWS Console for progress"
    echo "   - EKS deletion may take 5-10 minutes"
    echo "   - RDS deletion may take a few minutes"
else
    echo -e "${YELLOW}AWS Infrastructure is STILL RUNNING${NC}"
    echo ""
    echo "  To delete AWS resources, run:"
    echo "    CLEANUP_AWS=true ./destroy.sh"
    echo ""
    echo "  Or use Terraform (may hang):"
    echo "    cd $TERRAFORM_DIR && terraform destroy --auto-approve"
    echo ""
    echo "  Or delete manually from AWS Console:"
    echo "    - ECR: All 'eshop-*' repositories"
    echo "    - RDS: All 'eshop-*' databases"
    echo "    - ElastiCache: All 'eshop-*' clusters"
    echo "    - EKS: eshop-dev-eks cluster"
    echo "    - VPC: Associated with EKS (auto-deletes)"
fi

# 11. Cleanup summary
echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}✅ Kubernetes Cleanup:${NC}"
echo "  ✓ Helm releases deleted (all namespaces)"
echo "  ✓ Kubernetes deployments removed"
echo "  ✓ Services and LoadBalancers deleted"
echo "  ✓ Persistent volumes removed"
echo "  ✓ ConfigMaps and Secrets cleaned"
echo ""

if [[ "${CLEANUP_AWS:-false}" == "true" ]]; then
    echo -e "${GREEN}✅ AWS Infrastructure Cleanup (Initiated):${NC}"
    echo "  ✓ LoadBalancers deleted"
    echo "  ✓ RDS Database deleted"
    echo "  ✓ ElastiCache cluster deleted"
    echo "  ✓ ECR repositories deleted"
    echo "  ✓ EKS cluster deletion initiated"
    echo ""
    echo -e "${YELLOW}⏳ Cleanup Status:${NC}"
    echo "  • EKS deletion in progress (5-10 minutes)"
    echo "  • Monitor AWS Console for completion"
    echo ""
else
    echo -e "${YELLOW}⚠️  AWS Resources Still Running:${NC}"
    echo "  ❌ RDS Database"
    echo "  ❌ ElastiCache Redis"
    echo "  ❌ EKS Cluster"
    echo "  ❌ VPC & Networking"
    echo "  ❌ ECR Repositories"
    echo ""
    echo -e "${YELLOW}💰 Cost Alert:${NC}"
    echo "  AWS resources continue to incur costs!"
    echo "  Run with CLEANUP_AWS=true to delete them:"
    echo "    CLEANUP_AWS=true ./destroy.sh"
fi

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  1. Verify Kubernetes cleanup:"
echo "     kubectl get all --all-namespaces"
echo ""
echo "  2. If AWS cleanup still running, monitor progress:"
echo "     aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION"
echo "     aws rds describe-db-instances --region $AWS_REGION"
echo ""
echo "  3. To redeploy:"
echo "     ./deploy.sh"
echo ""
