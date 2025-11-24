# Grafana Dashboards & Alertmanager Email Notifications

Comprehensive guide for monitoring eShop infrastructure and applications with Grafana dashboards and email-based alerts.

## Overview

This module provides:

- **5 Pre-built Grafana Dashboards**: Infrastructure, Application Performance, RabbitMQ, Database, Cluster Health
- **Email-based Alert Notifications**: Automatic alerts sent to dev team via SMTP
- **Alert Rules**: 15+ alerts for critical infrastructure and application issues
- **Severity-based Routing**: Critical alerts sent immediately, warnings batched every 10 minutes

## Dashboards

### 1. Infrastructure Dashboard

**Purpose**: Monitor EKS cluster node and resource health

**Metrics**:

- Node CPU Usage (%) - identifies resource-constrained nodes
- Node Memory Usage (%) - monitors memory pressure
- Running Pods per Node - load distribution tracking
- Network I/O (Receive) - bandwidth utilization

**Use Cases**:

- Detect node overload or resource exhaustion
- Plan capacity scaling
- Identify network bottlenecks

**Access**: `Dashboards → eShop Infrastructure Dashboard`

---

### 2. Application Performance Dashboard

**Purpose**: Monitor API services and application health

**Metrics**:

- Request Throughput by Service (req/s) - API load analysis
- Response Latency (P95/P99) - end-user experience tracking
- Error Rate by Service (%) - application stability
- HTTP Status Code Distribution - request outcome breakdown

**Services Monitored**:

- basket-api
- catalog-api
- ordering-api
- identity-api
- webhooks-api

**Use Cases**:

- Track API performance degradation
- Identify slow endpoints
- Monitor error rates and anomalies
- Correlate errors with deployments

**Access**: `Dashboards → eShop Application Performance Dashboard`

---

### 3. RabbitMQ Dashboard

**Purpose**: Monitor message broker health and throughput

**Metrics**:

- Queue Depth (Ready Messages) - message backlog tracking
- Message Rate (Delivered/Redelivered) - throughput analysis
- Connections & Channels - connection pool status
- Memory Usage - broker resource utilization

**Thresholds**:

- Queue Depth Warning: > 5,000 messages
- Queue Depth Critical: > 10,000 messages
- Memory Usage Warning: > 70%
- Memory Usage Critical: > 90%

**Use Cases**:

- Detect message processing bottlenecks
- Monitor consumer lag
- Capacity planning for queue systems
- Troubleshoot consumer failures

**Access**: `Dashboards → eShop RabbitMQ Dashboard`

---

### 4. Database Dashboard

**Purpose**: Monitor PostgreSQL performance and health

**Metrics**:

- Active Connections by Database - connection pool monitoring
- Query Rate (DML) - insert/update/delete operations
- Slow Query Rate - queries exceeding 1 second threshold
- Cache Hit Ratio - memory efficiency

**Thresholds**:

- Active Connections Warning: > 80 connections
- Active Connections Critical: > 90 connections
- Cache Hit Ratio Target: > 98%
- Cache Hit Ratio Warning: < 95%

**Use Cases**:

- Identify N+1 query problems
- Optimize slow queries
- Monitor index effectiveness
- Plan database scaling

**Access**: `Dashboards → eShop Database Dashboard`

---

### 5. Cluster Health Dashboard

**Purpose**: Overall cluster status and pod lifecycle monitoring

**Metrics**:

- Service Status (Kubernetes API, RabbitMQ, PostgreSQL) - critical component health
- Pod Status by Namespace - running/pending/failed breakdown
- Pod Restart Rate (Last Hour) - stability indicator
- Node Status Overview - ready/not-ready nodes

**Use Cases**:

- Quick cluster health check
- Identify unstable services
- Detect CrashLoopBackOff pods
- Monitor node availability

**Access**: `Dashboards → eShop Cluster Health Dashboard`

---

## Alert Rules

### Critical Alerts (Immediate Notification)

These alerts are sent immediately when triggered.

#### Infrastructure Alerts

| Alert Name                    | Condition                               | Action                                  |
| ----------------------------- | --------------------------------------- | --------------------------------------- |
| **KubernetesPodCrashLooping** | Pod restarting > 0.1 times/min for 5min | Check pod logs, investigate crash cause |
| **KubernetesNodeNotReady**    | Node ready condition = false for 5min   | SSH to node, check kubelet status       |
| **ServiceDown**               | Service health check failing for 5min   | Restart service, check pod logs         |
| **PostgreSQLDown**            | PostgreSQL not responding for 5min      | Check database logs, failover if HA     |
| **RabbitMQDown**              | RabbitMQ not responding for 5min        | Restart RabbitMQ, check disk space      |

#### Application Alerts

| Alert Name                 | Condition                        | Action                                          |
| -------------------------- | -------------------------------- | ----------------------------------------------- |
| **HighErrorRate**          | Error rate > 5% for 5min         | Check service logs, review recent deployments   |
| **HighLatency**            | P95 latency > 1 second for 10min | Check resource usage, investigate slow queries  |
| **RabbitMQQueueDepthHigh** | Queue depth > 10,000 for 5min    | Increase consumer instances, check for blocking |

### Warning Alerts (Batched Every 10 Minutes)

Multiple warning alerts are grouped and sent once per 10-minute interval.

| Alert Name                    | Condition                           | Action                                         |
| ----------------------------- | ----------------------------------- | ---------------------------------------------- |
| **KubernetesPodNotHealthy**   | Pod in Pending/Failed state > 15min | Check resource requests, node capacity         |
| **ContainerCpuUsageHigh**     | CPU usage > 90% for 10min           | Optimize code or scale horizontally            |
| **ContainerMemoryUsageHigh**  | Memory usage > 90% for 10min        | Adjust memory limits or scale                  |
| **RabbitMQMemoryHigh**        | RabbitMQ memory > 90% for 5min      | Increase available memory or purge queues      |
| **PostgreSQLConnectionsHigh** | Active connections > 80 for 5min    | Review connection pool config, increase limits |
| **PostgreSQLSlowQueries**     | Slow queries > 0.5/sec for 5min     | Optimize slow queries, add indexes             |
| **HighRequestRate**           | Request rate > 1000 req/s for 5min  | Monitor for DDoS or load testing               |

### Info Alerts (Suppressed)

These alerts are recorded but not sent to avoid email noise:

- Pod restart detected
- Deployment rolling update
- Node memory/disk pressure

---

## Email Notification Configuration

### Setup Instructions

#### 1. Gmail Configuration (Recommended for Development)

1. Enable 2-Factor Authentication on your Gmail account
2. Generate App Password: https://myaccount.google.com/apppasswords
3. Create a new app (select "Mail" and "Windows Computer")
4. Copy the 16-character password

```bash
# In terraform.tfvars
alertmanager_email_from = "alerts@eshop.de"
alertmanager_email_to = ["devops@eshop.de", "team@eshop.de"]
alertmanager_smtp_host = "smtp.gmail.com"
alertmanager_smtp_port = 587
alertmanager_smtp_user = "your-email@gmail.com"
alertmanager_smtp_password = "xxxx xxxx xxxx xxxx"  # 16-char app password
```

#### 2. Office 365 Configuration

```bash
alertmanager_smtp_host = "smtp.office365.com"
alertmanager_smtp_port = 587
alertmanager_smtp_user = "your-email@company.com"
alertmanager_smtp_password = "your-office365-password"
```

#### 3. Custom SMTP Server

```bash
alertmanager_smtp_host = "mail.example.com"
alertmanager_smtp_port = 587  # or 25, 465 depending on server
alertmanager_smtp_user = "alerts@example.com"
alertmanager_smtp_password = "password"
```

### Email Templates

#### Critical Alert Email

Subject: `🚨 CRITICAL: AlertName - IMMEDIATE ACTION REQUIRED`

Content includes:

- Alert name and severity badge
- Affected service/pod/instance
- Detailed description and annotation
- Timestamp and recommended actions
- Links to Prometheus and Grafana

**Example**:

```
🚨 CRITICAL ALERT 🚨

Alert: ServiceDown
Component: application
Severity: CRITICAL

Instance: basket-api-5d4f9c6b9c-2km8x
Summary: Service is down (service basket-api)
Description: Service basket-api on instance 10.0.1.45 is down

Actions:
1. Review the alert details immediately
2. Check Prometheus: http://prometheus.example.com/alerts
3. Check Grafana: http://grafana.example.com
4. If service is down, initiate incident response
```

#### Warning Alert Email

Subject: `[WARNING] AlertName - Status: firing`

Content includes:

- Alert summary with color-coded severity
- Table of affected instances
- Detailed annotations
- Links to dashboards

---

## Integration with Dashboards

### Add Grafana Panel for Email Status

1. Open any dashboard
2. Click "Add Panel"
3. Select "Prometheus" datasource
4. Enter query:

```promql
ALERTS{severity="critical", alertstate="firing"}
```

5. Set visualization to "Table"
6. Save panel

### Create Alert Notification Channel

1. Go to Grafana → Alerting → Notification Channels
2. Click "New Channel"
3. Select "Email"
4. Configure:
   - Email addresses: `devops@eshop.de`
   - Send on all alerts: Enabled
5. Save

---

## Deployment

### Enable Alerts and Dashboards

In `terraform.tfvars`:

```hcl
# Monitoring Stack
monitoring_enabled                  = true
alertmanager_enabled               = true
grafana_enabled                    = true

# Email Configuration
alertmanager_email_from = "alerts@eshop.de"
alertmanager_email_to = [
  "devops@eshop.de",
  "on-call@eshop.de"
]
alertmanager_smtp_host = "smtp.gmail.com"
alertmanager_smtp_port = 587
alertmanager_smtp_user = "your-email@gmail.com"
alertmanager_smtp_password = "xxxx xxxx xxxx xxxx"
```

### Deploy

```bash
cd infra/terraform/envs/dev

terraform plan -target=module.monitoring
terraform apply -target=module.monitoring
```

### Verify Dashboards

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access in browser
# URL: http://localhost:3000
# Username: admin
# Password: (from terraform outputs)
```

### Test Email Notifications

1. Go to Prometheus: `kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090`
2. Navigate to `Alerts` tab
3. Manually trigger test alert by querying:

```promql
up{job="kubernetes-apiservers"} == 999
```

4. Check email inbox for critical alert notification

---

## Troubleshooting

### Dashboards Not Appearing in Grafana

1. Check ConfigMaps created:

```bash
kubectl get configmap -n monitoring | grep grafana-dashboard
```

2. Verify labels are correct:

```bash
kubectl get configmap grafana-dashboard-infrastructure-dashboard -n monitoring -o yaml | grep grafana_dashboard
```

3. Restart Grafana pod:

```bash
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
```

### Emails Not Being Sent

1. Check Alertmanager pod logs:

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager -f
```

2. Verify SMTP credentials:

```bash
# Test SMTP connection from pod
kubectl exec -it -n monitoring <alertmanager-pod> -- \
  telnet smtp.gmail.com 587
```

3. Check alert status in Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
# Go to http://localhost:9090/alerts
```

4. Verify email address format:

```bash
# Check ConfigMap
kubectl get configmap alertmanager-email-config -n monitoring -o yaml
```

### High Alert Volume

If receiving too many alerts:

1. Adjust grouping in `alertmanager-email-config.yaml`:

```yaml
group_wait: 30s # Wait 30 seconds before sending first alert
group_interval: 15m # Regroup every 15 minutes (instead of 10m)
```

2. Reduce alert frequency by increasing `for` duration in alert rules
3. Create inhibition rules to suppress lower-priority alerts when critical ones fire

---

## Best Practices

### Alert Naming

Follow convention: `ComponentStateCondition`

- ✅ Good: `RabbitMQMemoryHigh`, `PostgreSQLSlowQueries`
- ❌ Bad: `Alert1`, `HighMemory`

### Alert Severity

- **critical**: Service down, data loss imminent - page on-call
- **warning**: Performance degraded, will become critical soon - notify team
- **info**: Routine operations - metrics only

### Runbook Links

Add runbook annotations to alerts:

```yaml
annotations:
  summary: "RabbitMQ is down"
  runbook: "https://wiki.example.com/runbooks/rabbitmq-down"
```

### Test Alerts Regularly

Schedule monthly test of alert workflow:

1. Trigger critical alert
2. Verify email received within 10 seconds
3. Document response time and team reaction
4. Update runbooks as needed

---

## Additional Resources

- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Alertmanager Email Configuration](https://prometheus.io/docs/alerting/latest/configuration/#email_config)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Runbooks & Playbooks](https://prometheus.io/docs/prometheus/latest/querying/examples/#ranging-queries)
