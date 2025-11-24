#!/bin/bash

# eShop Microservices Deployment Script
# Deploys all eShop services after infrastructure is ready
# Usage: ./deploy-services.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 eShop Microservices Deployment${NC}"
echo "========================================"
echo ""

# Configuration
CLUSTER_NAME="${EKS_CLUSTER_NAME:-eshop-dev-eks}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com}"
NAMESPACE="eshop-services"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"

# 1. Verify Prerequisites
echo -e "${YELLOW}📋 Step 1: Verify Prerequisites${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}  ❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo "  ✅ kubectl available"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}  ❌ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi
echo "  ✅ AWS CLI available"

# 2. Configure kubectl access
echo -e "${YELLOW}📋 Step 2: Configure kubectl Access${NC}"
echo "  🔧 Updating kubeconfig for EKS cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --no-verify-ssl

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}  ❌ Cannot connect to cluster.${NC}"
    exit 1
fi
echo "  ✅ kubectl configured successfully"

# 3. Wait for EKS cluster to be ready
echo -e "${YELLOW}📋 Step 3: Wait for EKS Cluster Ready${NC}"
echo "  ⏳ Checking cluster status..."
RETRIES=0
MAX_RETRIES=60
while [[ $(kubectl get nodes 2>/dev/null | grep Ready | wc -l) -lt 1 ]]; do
    if [[ $RETRIES -ge $MAX_RETRIES ]]; then
        echo -e "${RED}  ❌ Cluster not ready after 5 minutes.${NC}"
        exit 1
    fi
    RETRIES=$((RETRIES+1))
    echo -n "."
    sleep 5
done
echo ""
echo "  ✅ Cluster nodes ready"
kubectl get nodes

# 4. Wait for monitoring stack to be ready
echo -e "${YELLOW}📋 Step 4: Wait for Monitoring Stack${NC}"
echo "  ⏳ Waiting for Prometheus and Grafana..."
RETRIES=0
while [[ $(kubectl get pods -n monitoring 2>/dev/null | grep Running | wc -l) -lt 2 ]]; do
    if [[ $RETRIES -ge 30 ]]; then
        echo -e "${YELLOW}  ⚠️  Monitoring not fully ready, but continuing...${NC}"
        break
    fi
    RETRIES=$((RETRIES+1))
    echo -n "."
    sleep 10
done
echo ""
echo "  ✅ Monitoring stack deployed"

# 5. Wait for RabbitMQ to be ready
echo -e "${YELLOW}📋 Step 5: Wait for RabbitMQ${NC}"
echo "  ⏳ Waiting for RabbitMQ broker..."
RETRIES=0
while [[ $(kubectl get pods -n rabbitmq 2>/dev/null | grep Running | wc -l) -lt 1 ]]; do
    if [[ $RETRIES -ge 30 ]]; then
        echo -e "${YELLOW}  ⚠️  RabbitMQ not fully ready, but continuing...${NC}"
        break
    fi
    RETRIES=$((RETRIES+1))
    echo -n "."
    sleep 10
done
echo ""
echo "  ✅ RabbitMQ deployed"

# 6. Create namespace for services
echo -e "${YELLOW}📋 Step 6: Create eShop Services Namespace${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "  ℹ️  Namespace already exists"
else
    echo "  🔧 Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
fi
echo "  ✅ Namespace ready"

# 7. Update Docker registry in manifests
echo -e "${YELLOW}📋 Step 7: Configure Docker Registry${NC}"
echo "  🔧 Registry: $DOCKER_REGISTRY"

# Create temporary manifest with registry substitution
MANIFEST_TEMP="/tmp/eshop-services-${RANDOM}.yaml"
sed "s|\$DOCKER_REGISTRY|$DOCKER_REGISTRY|g" "$K8S_DIR/eshop-services.yaml" > "$MANIFEST_TEMP"
echo "  ✅ Manifest updated"

# 8. Deploy all services
echo -e "${YELLOW}📋 Step 8: Deploy eShop Microservices${NC}"
echo "  🚀 Deploying services..."

if kubectl apply -f "$MANIFEST_TEMP"; then
    echo "  ✅ Services deployed successfully"
else
    echo -e "${RED}  ❌ Deployment failed.${NC}"
    rm "$MANIFEST_TEMP"
    exit 1
fi

rm "$MANIFEST_TEMP"

# 9. Wait for services to be ready
echo -e "${YELLOW}📋 Step 9: Wait for Services Ready${NC}"
echo "  ⏳ Waiting for all pods to be running..."

# Wait for Identity API
echo "  Waiting for Identity.API..."
kubectl rollout status deployment/identity-api -n $NAMESPACE --timeout=5m

# Wait for Catalog API
echo "  Waiting for Catalog.API..."
kubectl rollout status deployment/catalog-api -n $NAMESPACE --timeout=5m

# Wait for Basket API
echo "  Waiting for Basket.API..."
kubectl rollout status deployment/basket-api -n $NAMESPACE --timeout=5m

# Wait for Ordering API
echo "  Waiting for Ordering.API..."
kubectl rollout status deployment/ordering-api -n $NAMESPACE --timeout=5m

# Wait for WebApp
echo "  Waiting for WebApp..."
kubectl rollout status deployment/webapp -n $NAMESPACE --timeout=5m

echo "  ✅ All services running"

# 10. Get LoadBalancer information
echo -e "${YELLOW}📋 Step 10: Service Information${NC}"

echo ""
echo -e "${GREEN}🎉 ===============================================${NC}"
echo -e "${GREEN}✅ eShop Services Deployment Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""

echo -e "${BLUE}📊 Deployed Services:${NC}"
kubectl get deployments -n $NAMESPACE -o wide

echo ""
echo -e "${BLUE}📡 Services:${NC}"
kubectl get svc -n $NAMESPACE -o wide

echo ""
echo -e "${BLUE}🔗 Access Information:${NC}"

# Get WebApp LoadBalancer
WEBAPP_LB=$(kubectl get svc webapp -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
if [[ "$WEBAPP_LB" == "pending" ]] || [[ -z "$WEBAPP_LB" ]]; then
    echo "  • WebApp:      http://<EXTERNAL-IP> (LoadBalancer pending, check: kubectl get svc webapp -n $NAMESPACE)"
else
    echo "  • WebApp:      http://$WEBAPP_LB"
fi

echo ""
echo -e "${YELLOW}🔗 Internal Service URLs (from within cluster):${NC}"
echo "  • Identity API:  http://identity-api:5001"
echo "  • Catalog API:   http://catalog-api:5010"
echo "  • Basket API:    http://basket-api:5011"
echo "  • Ordering API:  http://ordering-api:5012"
echo "  • Webhooks API:  http://webhooks-api:5013"
echo "  • Webhook Client: http://webhook-client:5014"

echo ""
echo -e "${YELLOW}📝 Port-Forward for Development:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/identity-api 5001:5001"
echo "  kubectl port-forward -n $NAMESPACE svc/catalog-api 5010:5010"
echo "  kubectl port-forward -n $NAMESPACE svc/basket-api 5011:5011"
echo "  kubectl port-forward -n $NAMESPACE svc/ordering-api 5012:5012"
echo "  kubectl port-forward -n $NAMESPACE svc/webapp 8080:80"

echo ""
echo -e "${YELLOW}📊 Monitor Services:${NC}"
echo "  kubectl get pods -n $NAMESPACE -w"
echo "  kubectl logs -n $NAMESPACE -l app=basket-api -f"

echo ""
echo -e "${YELLOW}🧹 Cleanup Services:${NC}"
echo "  kubectl delete namespace $NAMESPACE"
echo "  Or run: ./destroy.sh && CLEANUP_AWS=true ./destroy.sh"

echo ""
