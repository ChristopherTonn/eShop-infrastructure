#!/bin/bash

# eShop Infrastructure Destruction Script
# Removes Kubernetes resources, local state, and optionally AWS infrastructure
# Works even if infrastructure was never created (clean cleanup)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}💥 eShop Infrastructure Cleanup${NC}"
echo "========================================"
echo ""

# Configuration
CLUSTER_NAME="${EKS_CLUSTER_NAME:-eshop-dev-eks}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
NAMESPACES=("default" "monitoring" "rabbitmq" "logging" "kube-system")

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

# 2. Check if EKS Cluster exists
echo -e "${YELLOW}�� Step 2: Check EKS Cluster Status${NC}"
CLUSTER_EXISTS=false
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null 2>&1; then
    CLUSTER_EXISTS=true
    echo "  ✅ EKS Cluster exists: $CLUSTER_NAME"
else
    echo "  ℹ️  EKS Cluster does not exist (clean state)"
fi

# 3. Kubernetes cleanup (only if cluster exists)
if [[ "$CLUSTER_EXISTS" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}📋 Step 3: Configure kubectl Access${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}  ❌ kubectl not found. Please install kubectl.${NC}"
        exit 1
    fi
    
    echo "  🔧 Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --no-verify-ssl 2>/dev/null || true
    
    if kubectl cluster-info &> /dev/null 2>&1; then
        echo "  ✅ kubectl configured successfully"
        
        # 3.1 Delete all Helm releases
        echo -e "${YELLOW}📋 Step 3.1: Delete Helm Releases${NC}"
        if command -v helm &> /dev/null; then
            ALL_NAMESPACES=$(helm list --all-namespaces --output json 2>/dev/null | jq -r '.[].namespace' | sort -u || echo "")
            if [[ -n "$ALL_NAMESPACES" ]]; then
                echo "  🗑️  Deleting Helm releases..."
                echo "$ALL_NAMESPACES" | while read -r ns; do
                    if [[ -n "$ns" ]]; then
                        RELEASES=$(helm list --namespace "$ns" --output json 2>/dev/null | jq -r '.[].name' || echo "")
                        if [[ -n "$RELEASES" ]]; then
                            echo "    Namespace: $ns"
                            echo "$RELEASES" | while read -r release; do
                                echo "      • Deleting: $release"
                                helm uninstall "$release" --namespace "$ns" 2>/dev/null || true
                            done
                        fi
                    fi
                done
                echo "  ✅ Helm releases deleted"
            fi
        fi
        
        # 3.2 Delete Kubernetes resources
        echo -e "${YELLOW}📋 Step 3.2: Delete Kubernetes Resources${NC}"
        echo "  🗑️  Deleting deployments, statefulsets, daemonsets, services..."
        for ns in "${NAMESPACES[@]}"; do
            if kubectl get namespace "$ns" &>/dev/null 2>&1; then
                kubectl delete deployments --all -n "$ns" --grace-period=30 2>/dev/null || true
                kubectl delete statefulsets --all -n "$ns" --grace-period=30 2>/dev/null || true
                kubectl delete daemonsets --all -n "$ns" --grace-period=30 2>/dev/null || true
                kubectl delete jobs --all -n "$ns" --grace-period=30 2>/dev/null || true
                kubectl delete services --all -n "$ns" 2>/dev/null || true
            fi
        done
        echo "  ✅ Kubernetes resources deleted"
        
        # 3.3 Delete PVCs
        echo -e "${YELLOW}📋 Step 3.3: Delete Persistent Volumes${NC}"
        echo "  🗑️  Deleting PVCs..."
        for ns in "${NAMESPACES[@]}"; do
            if kubectl get namespace "$ns" &>/dev/null 2>&1; then
                kubectl delete pvc --all -n "$ns" 2>/dev/null || true
            fi
        done
        echo "  ✅ PVCs deleted"
        
        # 3.4 Wait for cleanup
        echo "  ⏳ Waiting for LoadBalancer cleanup (30s)..."
        sleep 30
    else
        echo "  ⚠️  Cannot connect to cluster - skipping K8s cleanup"
    fi
fi

# 4. Clean up local Terraform state files
echo -e "${YELLOW}📋 Step 4: Clean up Local Terraform State${NC}"
TERRAFORM_DIR="terraform/envs/dev"
if [[ -d "$TERRAFORM_DIR" ]]; then
    echo "  🧹 Removing local state files..."
    rm -f "$TERRAFORM_DIR/terraform.tfstate"* "$TERRAFORM_DIR/tfplan"* "$TERRAFORM_DIR/.terraform.lock.hcl" 2>/dev/null || true
    echo "  ✅ Local state files cleaned"
fi

# 5. AWS Infrastructure Cleanup
echo -e "${YELLOW}📋 Step 5: AWS Infrastructure Cleanup${NC}"
echo ""

if [[ "${CLEANUP_AWS:-false}" == "true" ]]; then
    echo -e "${RED}⚠️  AWS CLEANUP ENABLED - Deleting AWS Resources${NC}"
    echo ""
    
    # 5.1 Delete ECR Repositories
    echo "  Step 5.1: Clean up ECR Repositories..."
    aws ecr describe-repositories --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.repositories[] | select(.repositoryName | contains("eshop")) | .repositoryName' | while read -r repo; do
        if [[ -n "$repo" ]]; then
            echo "    • Deleting ECR repo: $repo"
            aws ecr delete-repository --repository-name "$repo" --force --region $AWS_REGION 2>/dev/null || true
        fi
    done
    echo "  ✅ ECR repositories handled"
    
    # 5.2 Delete LoadBalancers
    echo "  Step 5.2: Clean up LoadBalancers..."
    aws elb describe-load-balancers --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.LoadBalancerDescriptions[].LoadBalancerName' | while read -r lb; do
        if [[ "$lb" == *"eshop"* ]]; then
            echo "    • Deleting LoadBalancer: $lb"
            aws elb delete-load-balancer --load-balancer-name "$lb" --region $AWS_REGION 2>/dev/null || true
        fi
    done
    echo "  ✅ LoadBalancers handled"
    
    # 5.3 Delete RDS
    echo "  Step 5.3: Clean up RDS Databases..."
    aws rds describe-db-instances --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.DBInstances[] | select(.DBInstanceIdentifier | contains("eshop")) | .DBInstanceIdentifier' | while read -r db; do
        if [[ -n "$db" ]]; then
            echo "    • Deleting RDS: $db"
            aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --region $AWS_REGION 2>/dev/null || true
        fi
    done
    echo "  ✅ RDS databases handled"
    
    # 5.4 Delete ElastiCache
    echo "  Step 5.4: Clean up ElastiCache Redis..."
    aws elasticache describe-cache-clusters --region $AWS_REGION --output json 2>/dev/null | \
    jq -r '.CacheClusters[] | select(.CacheClusterId | contains("eshop")) | .CacheClusterId' | while read -r cache; do
        if [[ -n "$cache" ]]; then
            echo "    • Deleting ElastiCache: $cache"
            aws elasticache delete-cache-cluster --cache-cluster-id "$cache" --region $AWS_REGION 2>/dev/null || true
        fi
    done
    echo "  ✅ ElastiCache clusters handled"
    
    # 5.5 Delete EKS Cluster
    if [[ "$CLUSTER_EXISTS" == "true" ]]; then
        echo "  Step 5.5: Clean up EKS Cluster (this may take 5-10 minutes)..."
        echo "    ⏳ Deleting EKS cluster: $CLUSTER_NAME"
        aws eks delete-cluster --name $CLUSTER_NAME --region $AWS_REGION 2>/dev/null || true
    fi
    
    # 5.6 Clean up Remote State (S3 + DynamoDB)
    echo "  Step 5.6: Clean up Remote Terraform State..."
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
    echo -e "${YELLOW}⏳ AWS Cleanup Status:${NC}"
    echo "  • EKS cluster deletion in progress (5-10 minutes)"
    echo "  • RDS, ElastiCache, ECR deletion initiated"
    echo "  • Monitor AWS Console for completion"
else
    echo -e "${YELLOW}AWS Infrastructure is STILL RUNNING${NC}"
    echo ""
    echo "  To delete AWS resources, run:"
    echo "    CLEANUP_AWS=true ./destroy.sh"
    echo ""
    echo -e "${YELLOW}💰 Cost Alert:${NC}"
    echo "  AWS resources continue to incur costs!"
    echo "  ~$0.50/hour for Phase 1 (VPC, EKS, RDS, ElastiCache)"
    echo "  +$8-10/hour if Phase 2 services are deployed"
fi

# 6. Summary
echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}✅ Cleanup Summary:${NC}"
echo "  ✓ Local Terraform state files removed"

if [[ "$CLUSTER_EXISTS" == "true" ]]; then
    echo "  ✓ Kubernetes resources deleted"
    echo "  ✓ Helm releases uninstalled"
    echo "  ✓ Services and PVCs removed"
fi

if [[ "${CLEANUP_AWS:-false}" == "true" ]]; then
    echo "  ✓ ECR repositories deleted"
    echo "  ✓ RDS databases deleted"
    echo "  ✓ ElastiCache clusters deleted"
    if [[ "$CLUSTER_EXISTS" == "true" ]]; then
        echo "  ✓ EKS cluster deletion initiated"
    fi
    echo "  ✓ Remote state (S3 + DynamoDB) cleaned"
fi

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  • To redeploy: ./deploy.sh"
echo "  • To check AWS cleanup status:"
echo "    aws eks list-clusters --region eu-central-1"
echo "    aws rds describe-db-instances --region eu-central-1"
echo ""
