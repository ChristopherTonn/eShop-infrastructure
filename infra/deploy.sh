#!/bin/bash

# eShop Re-Deployment Script
# Automatisiert sauberes Setup der kompletten Infrastruktur

set -e  # Exit bei Fehlern

echo "🚀 eShop Infrastructure Re-Deployment"
echo "=====================================

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Terraform Infrastruktur
echo -e "${YELLOW}📋 Step 1: Terraform Infrastructure${NC}"
cd terraform/envs/dev
terraform validate
terraform plan
terraform apply -auto-approve
cd ../../../

# 2. EKS Cluster Zugang konfigurieren  
echo -e "${YELLOW}📋 Step 2: Configure EKS Access${NC}"
cd terraform/envs/dev
aws eks update-kubeconfig --region eu-central-1 --name $(terraform output -raw cluster_name)

# 3. ECR Login
echo -e "${YELLOW}📋 Step 3: ECR Login${NC}"
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_registry)

# 4. Docker Images bauen und pushen
echo -e "${YELLOW}📋 Step 4: Build and Push Images${NC}"
ECR_REGISTRY=$(terraform output -raw ecr_registry)
cd ../../../

# Test Service Image
docker build --platform linux/amd64 -f Dockerfile.test -t eshop-test:linux .
docker tag eshop-test:linux $ECR_REGISTRY/eshop-webapp:linux
docker push $ECR_REGISTRY/eshop-webapp:linux

# 5. Kubernetes Deployment
echo -e "${YELLOW}📋 Step 5: Deploy to Kubernetes${NC}"

# Create dynamic deployment manifest
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
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

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

kubectl apply -f eshop-deployment-dynamic.yaml

# 6. Warten auf Deployment
echo -e "${YELLOW}📋 Step 6: Wait for Deployment${NC}"
kubectl rollout status deployment/eshop-webapp --timeout=300s

# 7. Service URL abrufen
echo -e "${YELLOW}📋 Step 7: Get Service URL${NC}"
sleep 30  # LoadBalancer braucht Zeit
EXTERNAL_IP=$(kubectl get service eshop-webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ ! -z "$EXTERNAL_IP" ]; then
  echo -e "${GREEN}✅ eShop deployed successfully!${NC}"
  echo -e "${GREEN}🔗 URL: http://$EXTERNAL_IP${NC}"
  echo -e "${GREEN}📊 Health: http://$EXTERNAL_IP/health${NC}"
  echo -e "${GREEN}📋 Info: http://$EXTERNAL_IP/info${NC}"
else
  echo -e "${RED}❌ LoadBalancer IP not ready yet${NC}"
  echo "Run: kubectl get service eshop-webapp-service"
fi

echo -e "${GREEN}🎉 Re-Deployment completed!${NC}"