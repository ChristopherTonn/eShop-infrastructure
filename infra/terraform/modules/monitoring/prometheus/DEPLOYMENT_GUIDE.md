# Monitoring Stack Deployment & Operations Guide

## Overview

This document describes the deployment, configuration, and operational procedures for the Prometheus + Grafana + Alertmanager stack on the eShop cluster.

## Architecture Components

```mermaid
┌──────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────── monitoring Namespace ───────────────┐   │
│  │                                                           │   │
│  │  ┌─────────────────┐     ┌──────────────────┐             │   │
│  │  │   Prometheus    │     │     Grafana      │             │   │
│  │  │  Server (x1)    │────►│  (Dashboards)    │             │   │
│  │  │  Port 9090      │     │  Port 80         │             │   │
│  │  └─────────────────┘     └──────────────────┘             │   │
│  │          ▲                                                │   │
│  │          │                                                │   │
│  │      ┌───┴────────────────────────────────┐               │   │
│  │      │                                    │               │   │
│  │  ┌───▼────────────┐     ┌─────────────┐   │               │   │
│  │  │  Prometheus    │     │  Alerting   │   │               │   │
│  │  │  Operator      │     │  Rules      │   │               │   │
│  │  └───────────────┘     │(PrometheusRu│    │               │   │
│  │  ┌─────────────────┐    │  le CRDs)   │   │               │   │
│  │  │ Node Exporter   │    └─────────────┘   │               │   │
│  │  │ (DaemonSet)     │                      │               │   │
│  │  └─────────────────┘                      │               │   │
│  │  ┌─────────────────┐     ┌──────────────┐ │               │   │
│  │  │kube-state-      │     │ Alertmanager │ │               │   │
│  │  │metrics          │     │ Port 9093    │ │               │   │
│  │  └─────────────────┘     └──────────────┘ │               │   │
│  │                                           │               │   │
│  └───────────────────────────────────────────┘               │   │
│                                                              │   │
│  ┌────────────────────── rabbitmq Namespace ──────────────┐  │   │
│  │                                                        │  │   │
│  │  ┌─────────────────┐                                   │  │   │
│  │  │  RabbitMQ       │──► Prometheus (Port 15692)        │  │   │
│  │  │  Prometheus     │──► Prometheus Metrics             │  │   │
│  │  │  Plugin         │                                   │  │   │
│  │  └─────────────────┘                                   │  │   │
│  │                                                        │  │   │
│  └────────────────────────────────────────────────────────┘  │   │
│                                                              │   │
└──────────────────────────────────────────────────────────────────┘
```

## 1. Prerequisites

- EKS Cluster (v1.28 or higher)
- Helm 3.10+
- kubectl configured
- Terraform 1.5+
- Storage Class available (gp2 or similar)

## 2. Deployment via Terraform

### 2.1 Configure Variables

```bash
cd infra/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and customize:

```hcl
monitoring_enabled = true
prometheus_chart_version = "25.3.1"
prometheus_replica_count = 1
prometheus_retention_days = 15
prometheus_storage_size = "10Gi"
```

### 2.2 Review Terraform Plan

```bash
terraform plan -target=module.monitoring
```

Important outputs:

- `monitoring_enabled`: true/false
- `prometheus_endpoint`: Service DNS
- `grafana_url`: Grafana access URL
- `grafana_admin_password`: Initial admin password

### 2.3 Execute Deployment

```bash
terraform apply -target=module.monitoring
```

Deployment takes approximately 2-5 minutes (Helm chart download + installation).

### 2.4 Verify Deployment

```bash
# Check namespace and pods
kubectl get ns | grep monitoring
kubectl get pods -n monitoring

# Check Helm release
helm list -n monitoring

# Check services
kubectl get svc -n monitoring
```

## 3. Access Services

### 3.1 Port-Forwarding for Local Development

```bash
# Terminal 1: Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090

# Terminal 2: Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Terminal 3: Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Access URLs:

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin / PASSWORD)
- Alertmanager: http://localhost:9093

### 3.2 In-Cluster Access

```yaml
# From other pods within the cluster
prometheus: http://kube-prometheus-stack.monitoring.svc.cluster.local:9090
grafana: http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80
alertmanager: http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093
```

### 3.3 Grafana Initial Setup

```bash
# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Retrieve admin password
terraform output grafana_admin_password

# Check Grafana secrets
kubectl get secret -n monitoring | grep grafana
```

## 4. Prometheus Configuration

### 4.1 Scrape Jobs

Prometheus automatically discovers:

1. **Kubernetes Components**: via kube-apiserver, kubelet, kube-scheduler
2. **RabbitMQ**: Port 15692 (Prometheus Plugin)
3. **Pod Annotations**: `prometheus.io/scrape=true`

### 4.2 Add Custom Targets

Example: Custom Exporter

```yaml
apiVersion: v1
kind: Service
metadata:
  name: custom-metrics
  namespace: default
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: custom-app
  ports:
    - name: metrics
      port: 8080
```

Prometheus will automatically scrape this service (within 30-60 seconds).

### 4.3 Adjust Scrape Interval

```bash
# In terraform.tfvars
prometheus_scrape_interval = 15  # Default: 30 seconds

terraform apply -target=module.monitoring
```

## 5. Alert Rules Configuration

### 5.1 Review Alert Rules

```bash
# View PrometheusRule
kubectl get prometheusrules -n monitoring
kubectl describe prometheusrule eshop-alerts -n monitoring

# Check Alert Status in Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
# Browser: http://localhost:9090/alerts
```

### 5.2 Customize Alert Rules

1. Edit `infra/terraform/modules/monitoring/prometheus/main.tf`
2. Modify `kubernetes_manifest.prometheus_rules` resource
3. Run Terraform apply:

```bash
terraform apply -target=module.monitoring
```

Example: New Alert Rule

```hcl
{
  alert = "MyCustomAlert"
  expr  = "up{job=\"myjob\"} == 0"
  for   = "5m"
  labels = {
    severity = "critical"
  }
  annotations = {
    summary = "My custom alert fired"
  }
}
```

### 5.3 Recording Rules

Recording rules are predefined for performance:

```promql
instance:node_cpu:rate5m           # Node CPU Usage
instance:node_memory_utilisation   # Node Memory Usage
kubernetes:container_memory_usage  # Container Memory
kubernetes:container_cpu_usage     # Container CPU
```

Use in PromQL:

```promql
# Instead of (slower live calculation):
rate(node_cpu_seconds_total{mode="idle"}[5m])

# Use Recording Rule (fast):
instance:node_cpu:rate5m
```

## 6. Alertmanager Configuration

### 6.1 Configure Notification Channels

By default, Alertmanager is deployed without external notifications. To enable notifications:

1. Create Alertmanager Config Secret:

```bash
kubectl create secret generic alertmanager-custom-config \
  --from-file=alertmanager.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -
```

2. Update Helm Values in `main.tf`:

```hcl
set {
  name  = "alertmanager.config.route.receiver"
  value = "slack"
}

set {
  name  = "alertmanager.config.receivers[0].slack_configs[0].api_url"
  value = var.slack_webhook_url
}
```

### 6.2 Alert Routing

Alertmanager routing configured in `alertmanager.yaml`:

```yaml
route:
  group_by: ["alertname", "cluster", "service"]
  group_wait: 30s # Wait 30s before first alert
  group_interval: 5m # Batch updates every 5 min
  repeat_interval: 12h # Repeat alert every 12h
  receiver: "default"

  routes:
    - match:
        severity: critical
      receiver: "critical"
      group_wait: 10s
      repeat_interval: 1h
```

## 7. Grafana Dashboards

### 7.1 Predefined Dashboards

kube-prometheus-stack automatically installs:

- Kubernetes / Compute Resources
- Kubernetes / Cluster Monitoring
- Prometheus / Prometheus Stats

### 7.2 Import Custom Dashboard

```bash
# RabbitMQ Dashboard (example)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

1. Open Grafana UI: http://localhost:3000
2. Dashboards → Import
3. Enter Grafana ID: 10991 (RabbitMQ)
4. Select DataSource: Prometheus
5. Click Import

### 7.3 Predefined RabbitMQ Dashboard

Included in repository: `infra/terraform/modules/monitoring/prometheus/grafana-dashboard-rabbitmq.json`

Import steps:

1. Grafana UI → Dashboards → Import
2. Upload JSON file
3. Select DataSource: Prometheus
4. Click Import

## 8. Query Metrics (PromQL)

### 8.1 Common Queries

```promql
# Node CPU Usage (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node Memory (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod Memory
sum by (pod, namespace) (container_memory_usage_bytes{pod!=""}) / 1024 / 1024

# RabbitMQ Status
rabbitmq_up

# RabbitMQ Queue Size
sum by (queue) (rabbitmq_queue_messages_ready)

# RabbitMQ Memory
rabbitmq_process_resident_memory_bytes / rabbitmq_resident_memory_limit_bytes * 100

# Container Restart Count
sum by (pod) (rate(kube_pod_container_status_restarts_total[1h]))

# API Response Time (if instrumented)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### 8.2 Using PromQL in Grafana

1. Open a dashboard
2. Click Edit Panel
3. Enter PromQL query
4. Click Save

## 9. Monitoring Customization

### 9.1 Change Retention Period

```hcl
# terraform.tfvars
prometheus_retention_days = 30  # Instead of 15

terraform apply -target=module.monitoring
```

**Warning**: When increasing, ensure sufficient storage is available!

### 9.2 Change Resource Limits

```hcl
prometheus_resources = {
  requests = {
    cpu    = "500m"
    memory = "1Gi"
  }
  limits = {
    cpu    = "2000m"
    memory = "4Gi"
  }
}
```

### 9.3 Increase Storage Size

```hcl
prometheus_storage_size = "50Gi"  # Instead of 10Gi

terraform apply -target=module.monitoring
```

PVC will be automatically resized.

## 10. Troubleshooting

### 10.1 Prometheus Not Scraping RabbitMQ

```bash
# Check RabbitMQ Service
kubectl get svc -n rabbitmq

# Test Port
kubectl exec -it -n rabbitmq <pod> -- netstat -tln | grep 15692

# Check Prometheus Config
kubectl logs -n monitoring kube-prometheus-stack-prometheus-0 | grep rabbitmq
```

### 10.2 Reset Grafana Password

```bash
# Generate new password
kubectl patch secret -n monitoring grafana \
  -p '{"data":{"admin-password":"'$(echo -n 'newpassword' | base64)'"}}'

# Restart Grafana pods
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
```

### 10.3 Alert Rules Not Visible

```bash
# Check PrometheusRule Status
kubectl get prometheusrules -n monitoring -o yaml

# Check Service Monitor
kubectl get servicemonitors -n monitoring

# Check Prometheus Logs for Errors
kubectl logs -n monitoring kube-prometheus-stack-prometheus-0 | grep -i "rule\|error"
```

### 10.4 Storage Full

```bash
# Check PVC Status
kubectl get pvc -n monitoring

# Check Prometheus Size
kubectl exec -it -n monitoring kube-prometheus-stack-prometheus-0 -- du -sh /prometheus

# Reduce Retention
prometheus_retention_days = 7
terraform apply -target=module.monitoring
```

## 11. Backup & Restore

### 11.1 Backup Prometheus Data

```bash
# Snapshot PVC (AWS)
aws ec2 create-snapshot \
  --volume-id <volume-id> \
  --description "Prometheus backup $(date +%Y-%m-%d)"

# Or: Export PVC Data
kubectl exec -it -n monitoring kube-prometheus-stack-prometheus-0 \
  -- tar czf - /prometheus | gzip > prometheus-backup.tar.gz
```

### 11.2 Export Grafana Dashboards

```bash
# Backup all dashboards
curl -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
  http://localhost:3000/api/search | jq '.[].id' | while read id; do
  curl -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
    http://localhost:3000/api/dashboards/uid/$id > dashboard-$id.json
done
```

## 12. Performance Tuning

### 12.1 Reduce Scrape Count

If Prometheus has high load:

```hcl
# Restrict ServiceMonitor Selector
set {
  name  = "prometheus.prometheusSpec.serviceMonitorSelector"
  value = jsonencode({
    matchLabels = {
      prometheus = "enabled"
    }
  })
}
```

Then only scrape services with label `prometheus: enabled`.

### 12.2 Increase Query Timeout

```hcl
set {
  name  = "prometheus.prometheusSpec.queryLogFile"
  value = "/prometheus/query.log"
}

set {
  name  = "prometheus.prometheusSpec.queryMaxConcurrency"
  value = "40"
}
```

## 13. Additional Resources

- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts
- Alertmanager: https://prometheus.io/docs/alerting/latest/
