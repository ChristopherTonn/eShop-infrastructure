# 📊 Monitoring & Alerting Runbook

Set up and manage monitoring, alerting, and incident detection.

**Navigation:** [← Disaster Recovery](DISASTER_RECOVERY.md) | [Next: Scaling →](SCALING.md)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [CloudWatch Setup](#cloudwatch-setup)
3. [Prometheus Metrics](#prometheus-metrics)
4. [Grafana Dashboards](#grafana-dashboards)
5. [Alert Rules](#alert-rules)
6. [Incident Response](#incident-response)

---

## 🔍 Overview

Three-layer monitoring approach:

1. **CloudWatch** - AWS native monitoring (logs, metrics, alarms)
2. **Prometheus** - Kubernetes metrics (performance, resource usage)
3. **Grafana** - Visualization and dashboarding

---

## 🔧 CloudWatch Setup

### Enable CloudWatch Logs

```bash
# Check if EKS logs are enabled
aws eks describe-cluster \
  --name eshop-eks \
  --region eu-central-1 \
  --query 'cluster.logging.clusterLogging'

# Enable logs if not already enabled
aws eks update-cluster-config \
  --name eshop-eks \
  --logging '{
    "clusterLogging": [
      {
        "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"],
        "enabled": true
      }
    ]
  }' \
  --region eu-central-1
```

### View Logs

```bash
# View EKS logs
aws logs tail /aws/eks/eshop-eks/cluster --follow

# View specific service logs
aws logs tail /aws/eks/eshop-eks/eshop/catalog-api --follow

# Filter by log level
aws logs filter-log-events \
  --log-group-name /aws/eks/eshop-eks/cluster \
  --filter-pattern "ERROR" \
  --region eu-central-1
```

---

## 📈 Prometheus Metrics

### Key Metrics to Monitor

| Metric                | Threshold   | Alert    |
| --------------------- | ----------- | -------- |
| CPU Usage             | > 80%       | Warning  |
| Memory Usage          | > 90%       | Warning  |
| Disk Usage            | > 85%       | Warning  |
| Pod Restart Count     | > 3 (5 min) | Critical |
| Request Latency (p99) | > 500ms     | Warning  |
| Error Rate            | > 1%        | Critical |
| Service Availability  | < 99.5%     | Critical |

### Query Metrics

```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Query PromQL examples:
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory usage
sum(container_memory_usage_bytes) by (pod)

# Request rate
sum(rate(http_requests_total[5m])) by (service)

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
```

---

## 📊 Grafana Dashboards

### Access Grafana

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser
open http://localhost:3000

# Login
# Username: admin
# Password: PASSWORD
```

### Create Custom Dashboard

1. **Home** → **New Dashboard** → **Add Panel**
2. **Query** tab:
   - Datasource: Prometheus
   - Metrics: Select from dropdown
3. **Visualization** tab:
   - Choose graph type (graph, gauge, table, etc.)
4. **Save** and give dashboard a name

### Important Dashboards

| Dashboard           | Purpose                     |
| ------------------- | --------------------------- |
| Cluster Overview    | Node health, resource usage |
| Deployment Status   | Pod count, restarts, errors |
| Service Performance | Latency, throughput, errors |
| Resource Usage      | CPU, memory, disk trends    |

---

## 🚨 Alert Rules

### CloudWatch Alarms

```bash
# Create CPU alert
aws cloudwatch put-metric-alarm \
  --alarm-name eshop-high-cpu \
  --alarm-description "Alert when CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:eu-central-1:123456789:incident-alerts

# Create Memory alert
aws cloudwatch put-metric-alarm \
  --alarm-name eshop-high-memory \
  --alarm-description "Alert when Memory > 90%" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold
```

### Prometheus Alert Rules

```yaml
# prometheus-rules.yaml
groups:
  - name: eshop-alerts
    rules:
      - alert: HighCPUUsage
        expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) > 0.8
        for: 5m
        annotations:
          summary: "Pod {{ $labels.pod }} has high CPU usage"

      - alert: HighErrorRate
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.01
        for: 5m
        annotations:
          summary: "Error rate above 1%"

      - alert: PodCrashLooping
        expr: increase(kube_pod_container_status_restarts_total[15m]) > 3
        annotations:
          summary: "Pod {{ $labels.pod }} is restarting too frequently"
```

---

## 🎯 Incident Response

### Detect Alert

```
Alert triggers → SNS → Email/Slack notification
```

### Investigate

```bash
# 1. Check alerting metric
# Via Grafana dashboard or Prometheus query

# 2. Check pod logs
kubectl logs -f deployment/AFFECTED_SERVICE -n eshop

# 3. Check pod resources
kubectl describe pod POD_NAME -n eshop

# 4. Check node health
kubectl describe node NODE_NAME
```

### Respond

Based on alert:

| Alert           | Response                          | Runbook                                             |
| --------------- | --------------------------------- | --------------------------------------------------- |
| High CPU        | Scale out or optimize code        | [Scaling](SCALING.md)                               |
| High Memory     | Identify memory leak, restart pod | [Scaling](SCALING.md)                               |
| High Error Rate | Check logs, rollback if needed    | [Incident Playbook](#)                              |
| Pod Crashing    | Check logs, fix config            | [Troubleshooting](../deployment/TROUBLESHOOTING.md) |
| Node Down       | Replace node (automatic)          | [Disaster Recovery](DISASTER_RECOVERY.md)           |

---

## 📞 Escalation

### Level 1: Auto-Recovery

- Kubernetes restarts failed pods
- CloudWatch alarms trigger SNS

### Level 2: On-Call

- Investigates alert
- Takes corrective action
- Documents incident

### Level 3: Escalation

- Contact team lead
- Critical alerts only (availability < 99%)

---

## 🔗 Related Documentation

- [Disaster Recovery](DISASTER_RECOVERY.md)
- [Scaling Guide](SCALING.md)
- [Architecture](../ARCHITECTURE.md)
- [Troubleshooting](../deployment/TROUBLESHOOTING.md)

---

**Last updated:** December 2025
