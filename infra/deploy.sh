#!/bin/bash

# eShop Re-Deployment Script - 2-Phase Infrastructure Deployment
# Phase 1: AWS Infrastructure (VPC, EKS, RDS, ElastiCache, ECR)
# Phase 2: Kubernetes Services (RabbitMQ, Prometheus, Grafana, Alertmanager, Fluent Bit)

set -e  # Exit on errors

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 eShop Infrastructure Re-Deployment"
echo "====================================="
echo "Working from: $SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function for retries
retry_command() {
    local retries=3
    local count=0
    until [ $count -ge $retries ]; do
        if "$@"; then
            break
        fi
        count=$((count+1))
        echo "Retry $count/$retries for: $*"
        sleep 5
    done
}

# Helper function to check if S3 bucket exists
bucket_exists() {
    # Try accessing the bucket directly (more accurate than ls)
    aws s3api head-bucket --bucket "$1" >/dev/null 2>&1
}

# Helper function to check if S3 bucket exists in our account
bucket_exists_our_account() {
    aws s3api get-bucket-location --bucket "$1" >/dev/null 2>&1
}

# Helper function to check if DynamoDB table exists
table_exists() {
    aws dynamodb describe-table --table-name "$1" >/dev/null 2>&1
}

# 0. Pre-Check: Ensure cleanliness
echo -e "${YELLOW}📋 Step 0: Pre-Deployment Cleanup${NC}"
echo "  🧹 Cleaning up any leftover state files..."
rm -rf terraform/bootstrap/.terraform terraform/bootstrap/.terraform.lock.hcl terraform/bootstrap/terraform.tfstate*
rm -rf terraform/envs/dev/.terraform terraform/envs/dev/.terraform.lock.hcl terraform/envs/dev/terraform.tfstate*
echo "  ✅ Local cleanup completed"

# 1. Smart Bootstrap - only if necessary
echo -e "${YELLOW}📋 Step 1: Smart Bootstrap Strategy${NC}"

cd terraform/bootstrap

# Check which resources are missing
DEV_BUCKET_EXISTS=false
DEV_TABLE_EXISTS=false
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="eshop-terraform-state-dev-$ACCOUNT_ID"  # Unique bucket name with account ID
TABLE_NAME="eshop-terraform-lock-dev"   # Standard table name

echo "  🎯 Using standard resource names:"
echo "    Bucket: $BUCKET_NAME"
echo "    Table: $TABLE_NAME"

if bucket_exists_our_account "$BUCKET_NAME"; then
    echo "  ✓ S3 bucket $BUCKET_NAME already exists"
    DEV_BUCKET_EXISTS=true
fi
if table_exists "$TABLE_NAME"; then
    echo "  ✓ DynamoDB table $TABLE_NAME already exists"
    DEV_TABLE_EXISTS=true
fi

if [[ "$DEV_BUCKET_EXISTS" == true && "$DEV_TABLE_EXISTS" == true ]]; then
    echo "  🎯 Bootstrap resources already exist - skipping bootstrap"
    terraform init -upgrade >/dev/null 2>&1 || true
    # Import existing resources to state
    echo "  🔄 Importing existing resources to terraform state..."
    terraform import aws_s3_bucket.terraform_state_dev eshop-terraform-state-dev >/dev/null 2>&1 || true
    terraform import aws_dynamodb_table.terraform_lock_dev eshop-terraform-lock-dev >/dev/null 2>&1 || true
    terraform import aws_s3_bucket_versioning.terraform_state_dev eshop-terraform-state-dev >/dev/null 2>&1 || true
    terraform import aws_s3_bucket_server_side_encryption_configuration.terraform_state_dev eshop-terraform-state-dev >/dev/null 2>&1 || true
    terraform import aws_s3_bucket_public_access_block.terraform_state_dev eshop-terraform-state-dev >/dev/null 2>&1 || true
    echo "  ✅ Import completed"
else
    echo "  🔧 Missing resources detected - creating bootstrap..."
    terraform init -upgrade
    
    # Create only missing resources
    if [[ "$DEV_BUCKET_EXISTS" == false ]]; then
        echo "  📦 Creating S3 bucket..."
        terraform apply -auto-approve -target=aws_s3_bucket.terraform_state_dev -target=aws_s3_bucket_versioning.terraform_state_dev -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state_dev -target=aws_s3_bucket_public_access_block.terraform_state_dev
    fi
    
    if [[ "$DEV_TABLE_EXISTS" == false ]]; then
        echo "  🔧 Creating DynamoDB table..."
        terraform apply -auto-approve -target=aws_dynamodb_table.terraform_lock_dev
    fi
    
    echo "  ✅ Bootstrap completed"
fi

cd ..

# 2. PHASE 1: AWS Infrastructure Deployment (VPC, EKS, RDS, ElastiCache, ECR)
echo -e "${YELLOW}📋 Step 2: PHASE 1 - AWS Infrastructure Deployment${NC}"
cd envs/dev

echo "  🔧 Initializing terraform..."
terraform init -upgrade

# Check backend status
echo "  📋 Checking backend connectivity..."
if ! terraform plan >/dev/null 2>&1; then
    echo "  ⚠️  Backend issues detected - fixing..."
    LOCK_ID=$(terraform plan 2>&1 | grep -o "ID: [a-zA-Z0-9-]*" | cut -d' ' -f2 | head -1) || true
    if [[ -n "$LOCK_ID" ]]; then
        echo "  🔓 Unlocking state: $LOCK_ID"
        terraform force-unlock -force "$LOCK_ID" >/dev/null 2>&1 || true
    fi
    terraform init -backend=true -force-copy -reconfigure
fi

echo "  ✅ Backend ready"
echo "  📋 Creating Phase 1 infrastructure plan (AWS only)..."
terraform validate
terraform plan -out=tfplan

echo "  🚀 Applying Phase 1: AWS Infrastructure..."
retry_command terraform apply tfplan

echo -e "${GREEN}✅ Phase 1 Complete: AWS Infrastructure deployed${NC}"
echo ""

# 2.1 Wait for EKS Cluster to be Ready
echo -e "${YELLOW}📋 Step 2.1: Waiting for EKS Cluster to be Ready${NC}"
CLUSTER_NAME=""
RETRIES=0
while [[ -z "$CLUSTER_NAME" && $RETRIES -lt 30 ]]; do
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "  ⏳ EKS cluster not ready yet, waiting 30s... ($((RETRIES+1))/30)"
        sleep 30
        RETRIES=$((RETRIES+1))
    fi
done

if [[ -z "$CLUSTER_NAME" ]]; then
    echo -e "${RED}  ❌ EKS cluster not accessible after 15 minutes${NC}"
    exit 1
fi

echo -e "${GREEN}✅ EKS Cluster Ready: $CLUSTER_NAME${NC}"
cd ../../../

# 3. Configure EKS Cluster Access
echo -e "${YELLOW}📋 Step 3: Configure EKS Access${NC}"
cd terraform/envs/dev

echo "  🔗 Configuring kubectl for cluster: $CLUSTER_NAME"
retry_command aws eks update-kubeconfig --region eu-central-1 --name "$CLUSTER_NAME"

# Check cluster readiness
echo "  📋 Checking cluster readiness..."
kubectl cluster-info --request-timeout=10s || echo "  ⚠️  Cluster not fully ready yet, continuing..."

cd ../../../

# 3.1 User Confirmation for Phase 2
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║ 🎯 PHASE 1 COMPLETE - Ready for Phase 2?          ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Phase 2 wird deployen:"
echo "  • RabbitMQ (Message Broker)"
echo "  • Prometheus & Grafana (Monitoring)"
echo "  • Alertmanager (Alerts)"
echo "  • Fluent Bit (Logging)"
echo ""
echo "Kosten Phase 2: +~$8-10/hour"
echo ""
read -p "Phase 2 jetzt starten? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Phase 2 übersprungen. Starte später mit: bash infra/deploy.sh --phase2${NC}"
    exit 0
fi

# 4. PHASE 2: Kubernetes Services Deployment
echo ""
echo -e "${YELLOW}📋 Step 4: PHASE 2 - Kubernetes Services Deployment${NC}"
cd terraform/envs/dev

echo "  🔧 Updating terraform configuration for Phase 2..."
echo "  📝 Enabling K8s modules (RabbitMQ, Monitoring, Logging)..."

# Update tfplan für Phase 2 mit enabled K8s-Services
terraform plan \
  -var="rabbitmq_enabled=true" \
  -var="monitoring_enabled=true" \
  -var="logging_enabled=true" \
  -var="fluent_bit_enabled=true" \
  -out=tfplan_phase2

echo "  🚀 Applying Phase 2: Kubernetes Services..."
retry_command terraform apply tfplan_phase2

echo -e "${GREEN}✅ Phase 2 Complete: Kubernetes Services deployed${NC}"
cd ../../../

# 5. ECR Login
echo -e "${YELLOW}📋 Step 5: ECR Login${NC}"
cd terraform/envs/dev
ECR_REGISTRY=""
RETRIES=0
while [[ -z "$ECR_REGISTRY" && $RETRIES -lt 10 ]]; do
    ECR_REGISTRY=$(terraform output -raw ecr_registry 2>/dev/null || echo "")
    if [[ -z "$ECR_REGISTRY" ]]; then
        echo "  ⏳ ECR registry not ready yet, waiting 10s... ($((RETRIES+1))/10)"
        sleep 10
        RETRIES=$((RETRIES+1))
    fi
done

if [[ -n "$ECR_REGISTRY" ]]; then
    echo "  🔗 Logging into ECR: $ECR_REGISTRY"
    retry_command aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"
else
    echo -e "${RED}  ❌ ECR registry not accessible${NC}"
    exit 1
fi

# 6. Build and Push Docker Images
echo -e "${YELLOW}📋 Step 6: Build and Push Images${NC}"
cd ../../../

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}  ❌ Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Test Service Image with error handling
echo "  🔨 Building Docker image..."
if [[ -f "Dockerfile.test" ]]; then
    retry_command docker build --platform linux/amd64 -f Dockerfile.test -t eshop-test:linux .
    docker tag eshop-test:linux "$ECR_REGISTRY/eshop-webapp:linux"
    echo "  📤 Pushing image to ECR..."
    retry_command docker push "$ECR_REGISTRY/eshop-webapp:linux"
    echo "  ✅ Image pushed successfully"
else
    echo -e "${RED}  ❌ Dockerfile.test not found${NC}"
    exit 1
fi

# 7. Kubernetes Deployment
echo -e "${YELLOW}📋 Step 7: Deploy to Kubernetes${NC}"

# Check if kubectl works
if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
    echo "  ⚠️  kubectl not ready, waiting for cluster..."
    sleep 30
    retry_command kubectl cluster-info --request-timeout=10s
fi

# Create dynamic deployment manifest with better error handling
echo "  🔨 Creating deployment manifest..."
cat > eshop-deployment-dynamic.yaml << MANIFEST
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eshop-webapp
  namespace: default
  labels:
    app: eshop-webapp
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: eshop-webapp
  template:
    metadata:
      labels:
        app: eshop-webapp
        component: frontend
    spec:
      containers:
      - name: eshop-webapp
        image: $ECR_REGISTRY/eshop-webapp:linux
        ports:
        - containerPort: 8080
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: eshop-webapp-service
  namespace: default
  labels:
    app: eshop-webapp
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: eshop-webapp

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: eshop-config
  namespace: default
data:
  app.name: "eShop Demo"
  app.version: "1.0.0"
  deployment.environment: "AWS EKS"
  infrastructure.status: "✅ Deployed Successfully"
  deployment.timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MANIFEST

echo "  🚀 Applying Kubernetes manifests..."
retry_command kubectl apply -f eshop-deployment-dynamic.yaml

# 8. Wait for Deployment
echo -e "${YELLOW}📋 Step 8: Wait for Deployment${NC}"
echo "  ⏳ Waiting for deployment to complete..."
retry_command kubectl rollout status deployment/eshop-webapp --timeout=600s

# 9. Get Service URL
echo -e "${YELLOW}📋 Step 9: Get Service URL${NC}"
echo "  ⏳ Waiting for LoadBalancer to get external IP..."
EXTERNAL_IP=""
RETRIES=0
while [[ -z "$EXTERNAL_IP" && $RETRIES -lt 20 ]]; do
    EXTERNAL_IP=$(kubectl get service eshop-webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [[ -z "$EXTERNAL_IP" ]]; then
        echo "  ⏳ LoadBalancer not ready yet, waiting 30s... ($((RETRIES+1))/20)"
        sleep 30
        RETRIES=$((RETRIES+1))
    fi
done

if [[ -n "$EXTERNAL_IP" ]]; then
  echo ""
  echo -e "${GREEN}🎉 ===============================================${NC}"
  echo -e "${GREEN}✅ eShop deployed successfully!${NC}"
  echo -e "${GREEN}🔗 URL: http://$EXTERNAL_IP${NC}"
  echo -e "${GREEN}📊 Health: http://$EXTERNAL_IP/health${NC}"
  echo -e "${GREEN}📋 Info: http://$EXTERNAL_IP/info${NC}"
  echo -e "${GREEN}🎉 ===============================================${NC}"
  echo ""
  echo -e "${YELLOW}📝 Next steps:${NC}"
  echo "   • Open the URL in your browser"
  echo "   • Check the health endpoint"
  echo "   • Monitor with: kubectl get pods,svc"
  echo "   • Cleanup with: ./destroy.sh"
else
  echo -e "${YELLOW}⚠️  LoadBalancer IP not ready yet after 10 minutes${NC}"
  echo "Run: kubectl get service eshop-webapp-service -w"
  echo "The service should become available shortly."
fi

echo ""
echo -e "${GREEN}🚀 Deployment Script Completed Successfully!${NC}"
echo -e "${GREEN}📊 Infrastructure Status: ✅ READY${NC}"
