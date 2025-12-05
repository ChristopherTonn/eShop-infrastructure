# 📈 Scaling Guide

Horizontal and vertical scaling strategies for eShop infrastructure.

**Navigation:** [← Monitoring](MONITORING_ALERTS.md) | [Next: Backups →](BACKUPS.md)

---

## 📋 Table of Contents

1. [Scaling Strategies](#scaling-strategies)
2. [Horizontal Pod Autoscaling (HPA)](#horizontal-pod-autoscaling)
3. [Cluster Autoscaling](#cluster-autoscaling)
4. [Vertical Scaling](#vertical-scaling)
5. [Database Scaling](#database-scaling)

---

## 🎯 Scaling Strategies

### When to Scale

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Usage | 70-80% | Scale out pods |
| Memory Usage | 80-90% | Scale out pods |
| Request Latency (p99) | > 500ms | Scale out |
| Node CPU | > 80% | Add nodes |
| RDS CPU | > 80% | Upgrade instance type |
| RDS Storage | > 80% | Expand volume |

---

## 🔄 Horizontal Pod Autoscaling (HPA)

### Enable HPA for a Service

```bash
# Create HPA based on CPU
kubectl autoscale deployment basket-api \
  --min=2 \
  --max=10 \
  --cpu-percent=70 \
  -n eshop

# View HPA status
kubectl get hpa -n eshop

# Describe HPA
kubectl describe hpa basket-api -n eshop
```

### Configure Advanced HPA

```yaml
# hpa-example.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: basket-api-hpa
  namespace: eshop
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: basket-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

### Monitor HPA

```bash
# Watch HPA status
kubectl get hpa -n eshop -w

# View HPA events
kubectl describe hpa basket-api -n eshop | tail -20

# Expected output when scaling:
# Metrics: cpu utilization 85% / 70%
# Desired replicas: 3
# Current replicas: 2
# Scale up in progress...
```

---

## 🖥️ Cluster Autoscaling

### Enable Cluster Autoscaling

```bash
# Check if Cluster Autoscaler is running
kubectl get deployment -n kube-system | grep autoscaler

# If not installed, add via Helm:
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=eshop-eks \
  --set awsRegion=eu-central-1
```

### Configure Node Group Scaling

```bash
# Set ASG limits for node scaling
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name eshop-eks-nodes \
  --min-size 2 \
  --max-size 10 \
  --region eu-central-1

# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name eshop-eks-nodes \
  --region eu-central-1 \
  --max-records 10
```

### Monitor Cluster Autoscaling

```bash
# Check node status
kubectl get nodes -w

# Describe node for capacity
kubectl describe node NODE_NAME

# Expected when scaling:
# 1. New pod pending (insufficient resources)
# 2. Cluster Autoscaler detects
# 3. New node provisioning (2-5 minutes)
# 4. Pod scheduled to new node
```

---

## 📊 Vertical Scaling

### Scale Database (RDS)

```bash
# Current instance class
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --query 'DBInstances[0].DBInstanceClass'

# Upgrade to larger instance
aws rds modify-db-instance \
  --db-instance-identifier eshop-postgres \
  --db-instance-class db.t3.small \
  --apply-immediately \
  --region eu-central-1

# Note: May cause brief downtime (few seconds)

# Verify upgrade
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --query 'DBInstances[0].{InstanceClass, EngineVersion, DBInstanceStatus}'
```

### Scale Redis (ElastiCache)

```bash
# Current node type
aws elasticache describe-cache-clusters \
  --cache-cluster-id eshop-redis \
  --query 'CacheClusters[0].CacheNodeType'

# Upgrade to larger node type
aws elasticache modify-cache-cluster \
  --cache-cluster-id eshop-redis \
  --cache-node-type cache.t3.small \
  --apply-immediately \
  --region eu-central-1

# Note: Causes brief downtime (~1-2 minutes)
```

### Scale Node Instance Type

```bash
# Update Terraform for larger instance
# infra/terraform/envs/dev/terraform.tfvars
# Change: eks_instance_types = ["t3.large"]  # was t3.medium

cd infra/terraform/envs/dev
terraform plan
terraform apply

# This will:
# 1. Create new node group with larger instances
# 2. Drain pods from old nodes
# 3. Schedule pods on new nodes
# 4. Delete old nodes
# Timeline: 10-15 minutes
```

---

## 🗄️ Database Scaling

### Scale RDS Storage

```bash
# Increase allocated storage
aws rds modify-db-instance \
  --db-instance-identifier eshop-postgres \
  --allocated-storage 50 \
  --apply-immediately \
  --region eu-central-1

# No downtime (AWS handles expansion)

# Verify
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --query 'DBInstances[0].AllocatedStorage'
```

### Add Read Replicas

```bash
# Create read replica for offloading read traffic
aws rds create-db-instance-read-replica \
  --db-instance-identifier eshop-postgres-read-1 \
  --source-db-instance-identifier eshop-postgres \
  --region eu-central-1

# View replicas
aws rds describe-db-instances \
  --query 'DBInstances[?ReadReplicaSourceDBInstanceIdentifier!=null]'

# Update connection strings to load-balance reads:
# Write queries → eshop-postgres (primary)
# Read queries → eshop-postgres-read-1 (replica)
```

---

## 📈 Scaling Runbook

### Before You Scale

```bash
# 1. Check current metrics
kubectl top nodes
kubectl top pods -n eshop

# 2. Verify no issues first
kubectl get pods -n eshop | grep -i error
kubectl logs -n eshop deployment/catalog-api | grep -i error

# 3. Understand the bottleneck
# CPU? Memory? I/O? Network?
```

### Scale Out (Add Pods)

```bash
# Manual scaling
kubectl scale deployment catalog-api --replicas=5 -n eshop

# Or use HPA (automatic)
kubectl autoscale deployment catalog-api \
  --min=3 --max=10 --cpu-percent=70
```

### Scale Up (Larger Instances)

```bash
# Vertical scaling requires infrastructure change
cd infra/terraform/envs/dev
terraform apply -var="eks_instance_types=[\"t3.large\"]"

# Wait for new nodes and pod migration (~15 min)
kubectl get nodes -w
```

---

## 🔗 Related Documentation

- [Monitoring & Alerting](MONITORING_ALERTS.md)
- [Backups & Retention](BACKUPS.md)
- [Infrastructure Overview](../infrastructure/README.md)
- [Terraform Guide](../infrastructure/TERRAFORM_GUIDE.md)

---

**Last updated:** December 2025
