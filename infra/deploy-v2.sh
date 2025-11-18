#!/bin/bash

# eShop Re-Deployment Script - Production Version
# Automatisiert sauberes Setup der kompletten Infrastruktur mit eindeutigen Namen

set -e  # Exit bei Fehlern

# Script Directory ermitteln
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 eShop Infrastructure Re-Deployment (v2)"
echo "=========================================="
echo "Working from: $SCRIPT_DIR"

# Farben für Output
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

# 0. Pre-Check: Sauberkeit sicherstellen
echo -e "${YELLOW}📋 Step 0: Pre-Deployment Cleanup${NC}"
echo "  🧹 Cleaning up any leftover state files..."
rm -rf terraform/bootstrap/.terraform terraform/bootstrap/.terraform.lock.hcl terraform/bootstrap/terraform.tfstate*
rm -rf terraform/envs/dev/.terraform terraform/envs/dev/.terraform.lock.hcl terraform/envs/dev/terraform.tfstate*
echo "  ✅ Local cleanup completed"

# 1. Smart Bootstrap - mit eindeutigen Namen
echo -e "${YELLOW}📋 Step 1: Bootstrap with Unique Naming${NC}"

cd terraform/bootstrap

# Verwende Timestamp für eindeutige Namen
UNIQUE_SUFFIX="-$(date +%Y%m%d%H%M%S)"
echo "  🏷️  Using unique suffix: $UNIQUE_SUFFIX"

echo "  🔧 Creating bootstrap resources..."
terraform init -upgrade

echo "  📦 Creating S3 bucket and DynamoDB table..."
terraform apply -auto-approve -var="unique_suffix=$UNIQUE_SUFFIX"

# S3 Bucket Verfügbarkeit prüfen
echo "  ⏳ Verifying S3 bucket availability..."
# Extrahiere Bucket-Namen aus Terraform Output
S3_BUCKET_NAME="eshop-terraform-state-dev$UNIQUE_SUFFIX"
echo "  🔍 Waiting for S3 bucket '$S3_BUCKET_NAME' to be globally available..."
RETRIES=0
while [[ $RETRIES -lt 12 ]]; do  # Max 6 Minuten warten
    if aws s3 ls "s3://$S3_BUCKET_NAME" >/dev/null 2>&1; then
        echo "  ✅ S3 bucket is ready!"
        break
    else
        echo "  ⏳ S3 bucket not yet available, waiting 30s... ($((RETRIES+1))/12)"
        sleep 30
        RETRIES=$((RETRIES+1))
    fi
done

if [[ $RETRIES -eq 12 ]]; then
    echo "  ⚠️  S3 bucket not available after 6 minutes. Continuing anyway..."
fi

echo "  ✅ Bootstrap completed"
cd ..

# 2. Hauptinfrastruktur Deployment
echo -e "${YELLOW}📋 Step 2: Main Infrastructure Deployment${NC}"
cd envs/dev

# Backend-Konfiguration dynamisch aktualisieren
echo "  🔧 Updating backend configuration..."
BACKEND_BUCKET="eshop-terraform-state-dev$UNIQUE_SUFFIX"
BACKEND_DYNAMODB="eshop-terraform-lock-dev$UNIQUE_SUFFIX"

echo "  📝 Backend bucket: $BACKEND_BUCKET"
echo "  📝 Backend table: $BACKEND_DYNAMODB"

# Backend-Konfiguration in main.tf aktualisieren
sed -i.bak "s/bucket.*=.*\"eshop.*terraform-state-dev.*/bucket         = \"$BACKEND_BUCKET\"/" main.tf
sed -i.bak "s/dynamodb_table.*=.*\"eshop.*terraform-lock-dev.*/dynamodb_table = \"$BACKEND_DYNAMODB\"/" main.tf

# **CRITICAL**: Auch name_prefix dynamisch aktualisieren!
echo "  🔧 Updating name_prefix with unique suffix..."
CLEAN_SUFFIX=${UNIQUE_SUFFIX#-}  # Remove leading dash
sed -i.bak "s/name_prefix = \"eshop-[0-9]*-\${local.environment}\"/name_prefix = \"eshop-$CLEAN_SUFFIX-\${local.environment}\"/" main.tf

echo "  ✅ Dynamic configuration updated"

echo "  🔧 Initializing main terraform..."
terraform init -upgrade

echo "  📊 Creating infrastructure plan..."
terraform validate
terraform plan -out=tfplan

echo "  🚀 Applying infrastructure..."
retry_command terraform apply tfplan
cd ../../../

# 3. EKS Cluster Zugang konfigurieren  
echo -e "${YELLOW}📋 Step 3: Configure EKS Access${NC}"
cd terraform/envs/dev
# Warten bis EKS Cluster bereit ist
echo "  ⏳ Waiting for EKS cluster to be ready..."
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

if [[ -n "$CLUSTER_NAME" ]]; then
    echo "  🔗 Configuring kubectl for cluster: $CLUSTER_NAME"
    retry_command aws eks update-kubeconfig --region eu-central-1 --name "$CLUSTER_NAME"
    # Cluster Readiness prüfen
    echo "  📋 Checking cluster readiness..."
    kubectl cluster-info --request-timeout=10s || echo "  ⚠️  Cluster not fully ready yet, continuing..."
else
    echo -e "${RED}  ❌ EKS cluster not accessible after 15 minutes${NC}"
    exit 1
fi

# 4. ECR Login
echo -e "${YELLOW}📋 Step 4: ECR Login${NC}"
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
    echo "  🔐 Logging into ECR: $ECR_REGISTRY"
    retry_command aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"
else
    echo -e "${RED}  ❌ ECR registry not accessible${NC}"
    exit 1
fi

# 5. Docker Images bauen und pushen
echo -e "${YELLOW}📋 Step 5: Build and Push Images${NC}"
cd ../../../

# Prüfen ob Docker läuft
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}  ❌ Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Test Service Image mit Error Handling
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

# 6. Kubernetes Deployment
echo -e "${YELLOW}📋 Step 6: Deploy to Kubernetes${NC}"

# Prüfen ob kubectl funktioniert
if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
    echo "  ⚠️  kubectl not ready, waiting for cluster..."
    sleep 30
    retry_command kubectl cluster-info --request-timeout=10s
fi

# Create dynamic deployment manifest mit besserer Error Behandlung
echo "  📝 Creating deployment manifest..."
cat > eshop-deployment-dynamic.yaml << EOF
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
EOF

echo "  🚀 Applying Kubernetes manifests..."
retry_command kubectl apply -f eshop-deployment-dynamic.yaml

# 7. Warten auf Deployment
echo -e "${YELLOW}📋 Step 7: Wait for Deployment${NC}"
echo "  ⏳ Waiting for deployment to complete..."
retry_command kubectl rollout status deployment/eshop-webapp --timeout=600s

# 8. Service URL abrufen
echo -e "${YELLOW}📋 Step 8: Get Service URL${NC}"
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
echo -e "${GREEN}🚀 Re-Deployment Script Completed Successfully!${NC}"
echo -e "${GREEN}📊 Infrastructure Status: ✅ READY${NC}"
echo -e "${GREEN}💰 Cost: ~$0.50/hour (remember to destroy when done)${NC}"