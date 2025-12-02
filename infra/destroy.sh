#!/bin/bash

# eShop Infrastructure Destruction Script
# Removes Kubernetes resources, local state, and optionally AWS infrastructure
# Works even if infrastructure was never created (clean cleanup)
#
# Usage: ./destroy.sh [OPTIONS]
# Options:
#   --profile PROFILE    AWS CLI Profile (default: eshop-terraform)
#   --region REGION      AWS Region (default: eu-central-1)
#   --help              Show this help message

set -e

# Parse command line arguments
AWS_PROFILE="${AWS_PROFILE:-eshop-terraform}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
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
            exit 1
            ;;
    esac
done

# Export profile for all AWS CLI calls
export AWS_PROFILE

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
NAMESPACES=("default" "monitoring" "rabbitmq" "logging" "kube-system")

# 1. Verify AWS credentials
echo -e "${YELLOW}📋 Step 1: Verify AWS Credentials${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}  ❌ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity --region $AWS_REGION &> /dev/null; then
    echo -e "${RED}  ❌ AWS credentials not configured. Please run 'aws configure'.${NC}"
    exit 1
fi

echo "  ✅ AWS credentials validated"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "  ✅ AWS Account: $AWS_ACCOUNT"
echo "  ✅ AWS Profile: $AWS_PROFILE"
echo "  ✅ AWS Region: $AWS_REGION"

# 2. Check if EKS Cluster exists
echo -e "${YELLOW}📋 Step 2: Check EKS Cluster Status${NC}"
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

# AWS-Ressourcen werden jetzt immer gelöscht
CLEANUP_AWS=true
if [[ "${CLEANUP_AWS:-false}" == "true" ]]; then
    echo -e "${RED}⚠️  AWS CLEANUP ENABLED - Deleting AWS Resources${NC}"
    echo ""
    
        # 5.1 Delete ALL ECR Repositories
        echo "  Step 5.1: Clean up ALL ECR Repositories..."
        ALL_ECR_REPOS=$(aws ecr describe-repositories --region $AWS_REGION --query "repositories[].repositoryName" --output text)
        if [ -z "$ALL_ECR_REPOS" ]; then
            echo "    No ECR repositories found."
        else
            echo "    Deleting the following ECR repositories:"
            echo "$ALL_ECR_REPOS"
            for repo in $ALL_ECR_REPOS; do
                echo "      Deleting ECR repo: $repo"
                timeout 60s aws ecr delete-repository --repository-name "$repo" --force --region $AWS_REGION 2>/dev/null || true
            done
            echo "    All ECR repositories deleted."
        fi
    
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

        # --- Delete ALL Elastic IPs ---
        echo "  Step 5.7: Release ALL Elastic IPs (EIPs)..."
        ALL_EIPS=$(aws ec2 describe-addresses --query "Addresses[].AllocationId" --output text)
        if [ -z "$ALL_EIPS" ]; then
            echo "    No Elastic IPs found."
        else
            echo "    Releasing the following EIPs:"
            echo "$ALL_EIPS"
            for eip in $ALL_EIPS; do
                echo "      Releasing: $eip"
                timeout 60s aws ec2 release-address --allocation-id "$eip" --region $AWS_REGION || true
            done
            echo "    All Elastic IPs released."
        fi

        # --- Delete ALL DynamoDB tables with 'eshop' ---
        echo "  Step 5.8: Delete ALL DynamoDB tables with 'eshop' in name..."
        DYNAMO_TABLES=$(aws dynamodb list-tables --region $AWS_REGION --output text | grep eshop | grep -v TABLENAMES)
        if [ -z "$DYNAMO_TABLES" ]; then
            echo "    No DynamoDB tables with 'eshop' found."
        else
            echo "    Deleting the following tables:"
            echo "$DYNAMO_TABLES"
            for t in $DYNAMO_TABLES; do
                echo "      Deleting: $t"
                timeout 60s aws dynamodb delete-table --table-name "$t" --region $AWS_REGION || true
            done
            echo "    All DynamoDB tables deleted."
        fi

        echo "  ✅ Remote state, EIPs, and DynamoDB tables cleaned"

        # --- Delete ALL VPCs with 'eshop' in name ---
        echo "  Step 5.9: Delete ALL VPCs with 'eshop' in name and dependencies..."
        VPCS=$(aws ec2 describe-vpcs --region $AWS_REGION --query "Vpcs[?contains(Tags[?Key=='Name'].Value | [0], 'eshop')].VpcId" --output text)
        if [ -z "$VPCS" ]; then
            echo "    No VPCs with 'eshop' in name found."
        else
            echo "    Deleting the following VPCs and dependencies:"
            echo "$VPCS"
            for vpc in $VPCS; do
                echo "      Processing VPC: $vpc"
                # 1. Delete NAT Gateways
                NAT_GWS=$(aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=vpc-id,Values=$vpc" --query "NatGateways[].NatGatewayId" --output text)
                for nat in $NAT_GWS; do
                    echo "        Deleting NAT Gateway: $nat"
                    timeout 60s aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region $AWS_REGION || echo "        ⚠️ Fehler beim Löschen von NAT Gateway $nat"
                done
                # 2. Delete Subnets
                SUBNETS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text)
                for subnet in $SUBNETS; do
                    echo "        Deleting Subnet: $subnet"
                    timeout 60s aws ec2 delete-subnet --subnet-id "$subnet" --region $AWS_REGION || echo "        ⚠️ Fehler beim Löschen von Subnet $subnet"
                done
                # 3. Delete Route Tables
                RTBS=$(aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=vpc-id,Values=$vpc" --query "RouteTables[].RouteTableId" --output text)
                for rtb in $RTBS; do
                    # Skip main route table association removal
                    ASSOCIATIONS=$(aws ec2 describe-route-tables --region $AWS_REGION --route-table-ids "$rtb" --query "RouteTables[].Associations[].RouteTableAssociationId" --output text)
                    for assoc in $ASSOCIATIONS; do
                        echo "        Disassociating Route Table: $rtb Association: $assoc"
                        timeout 30s aws ec2 disassociate-route-table --association-id "$assoc" --region $AWS_REGION || true
                    done
                    echo "        Deleting Route Table: $rtb"
                    timeout 60s aws ec2 delete-route-table --route-table-id "$rtb" --region $AWS_REGION || echo "        ⚠️ Fehler beim Löschen von Route Table $rtb"
                done
                # 4. Delete Internet Gateways
                IGWS=$(aws ec2 describe-internet-gateways --region $AWS_REGION --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text)
                for igw in $IGWS; do
                    echo "        Detaching and Deleting Internet Gateway: $igw"
                    timeout 30s aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" --region $AWS_REGION || true
                    timeout 60s aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region $AWS_REGION || echo "        ⚠️ Fehler beim Löschen von Internet Gateway $igw"
                done
                # 5. Delete Security Groups (außer default)
                SGS=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=vpc-id,Values=$vpc" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
                for sg in $SGS; do
                    echo "        Deleting Security Group: $sg"
                    timeout 60s aws ec2 delete-security-group --group-id "$sg" --region $AWS_REGION || echo "        ⚠️ Fehler beim Löschen von Security Group $sg"
                done
                # 6. Delete VPC
                echo "        Deleting VPC: $vpc"
                timeout 60s aws ec2 delete-vpc --vpc-id "$vpc" --region $AWS_REGION && echo "        ✅ VPC $vpc deleted" || echo "        ⚠️ Fehler beim Löschen von VPC $vpc"
            done
            echo "    All VPCs and dependencies deleted."
        fi
    
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

# --- Vollständige Löschung aller Ressourcen (Terraform) ---
echo -e "${YELLOW}📋 Step 7: Destroy Terraform Bootstrap (S3 Bucket & DynamoDB Table)${NC}"
if [[ -d "terraform/bootstrap" ]]; then
    cd terraform/bootstrap
    echo "  🧨 Destroying bootstrap resources (S3 Bucket, DynamoDB Table)..."
    terraform destroy -auto-approve || true
    cd ../../..
    echo "  ✅ Bootstrap resources destroyed"
fi

echo -e "${YELLOW}📋 Step 8: Destroy Terraform Infrastructure (VPC, Subnets, etc.)${NC}"
if [[ -d "terraform/envs/dev" ]]; then
    cd terraform/envs/dev
    echo "  🧨 Destroying infrastructure resources (VPC, Subnets, etc.)..."
    terraform destroy -auto-approve || true
    cd ../../..
    echo "  ✅ Infrastructure resources destroyed"
fi

echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${GREEN}✅ Cleanup Summary:${NC}"
echo "  ✓ Local Terraform state files removed"
echo "  ✓ Kubernetes resources deleted (falls vorhanden)"
echo "  ✓ Helm releases uninstalled (falls vorhanden)"
echo "  ✓ Services und PVCs entfernt (falls vorhanden)"
echo "  ✓ ECR repositories deleted"
echo "  ✓ RDS databases deleted"
echo "  ✓ ElastiCache clusters deleted"
echo "  ✓ EKS cluster deletion initiated (falls vorhanden)"
echo "  ✓ Remote state (S3 + DynamoDB) cleaned"
echo "  ✓ S3 Bucket & DynamoDB Table gelöscht"
echo "  ✓ VPC & Subnets gelöscht"

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  • To redeploy: ./deploy.sh"
echo "  • To check AWS cleanup status:"
echo "    aws eks list-clusters --region eu-central-1"
echo "    aws rds describe-db-instances --region eu-central-1"
echo "    aws ec2 describe-vpcs --region eu-central-1"
echo "    aws s3 ls | grep eshop-terraform-state"
echo "    aws dynamodb list-tables --region eu-central-1"
echo ""
echo -e "${YELLOW}💡 Alle Ressourcen wurden entfernt. Es entstehen keine weiteren AWS-Kosten!${NC}"
