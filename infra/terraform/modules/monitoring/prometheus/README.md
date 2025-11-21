# Prometheus Stack Helm Module

Terraform module for deploying **Prometheus**, **Grafana**, and **Alertmanager** in Kubernetes cluster via kube-prometheus-stack Helm Chart.

## Overview

This module provides a complete monitoring stack:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert management and notifications
- **Node Exporter**: Hardware and host metrics
- **kube-state-metrics**: Kubernetes object metrics
- **Prometheus Operator**: ServiceMonitor and PrometheusRule CRD support

## Features

### Metrics Sources (Scrape Targets)

- **Kubernetes Components**: kube-apiserver, kubelet, kube-scheduler, kube-controller-manager
- **RabbitMQ**: Prometheus Plugin (Port 15692) and Management API
- **Node Hardware**: CPU, Memory, Disk, Network (via Node Exporter)
- **Pod & Container**: CPU, Memory, Network (via cAdvisor)
- **Custom Annotations**: Pods with `prometheus.io/scrape=true` label

### Alert Rules

Predefined alert rules for:
- **Kubernetes**: Pod Crash Loops, Node Status, Memory/Disk Pressure
- **RabbitMQ**: Availability, Memory, unacked Messages, Connections
- **Container Resources**: High CPU/Memory Usage
- **Recording Rules**: Pre-compiled aggregations for better performance

### Grafana Dashboards

The kube-prometheus-stack chart includes predefined dashboards:
- Kubernetes Cluster Overview
- Kubernetes Node Exporter
- Prometheus Stats
- RabbitMQ Overview (when added manually)

## Usage

### Basic Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring/prometheus"

  namespace                  = "monitoring"
  enabled                    = true
  chart_version              = "25.3.1"
  prometheus_replica_count   = 1
  retention_days             = 15
  storage_size               = "10Gi"
  prometheus_resources = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }

  tags = {
    Environment = "development"
  }
}
```

## Input Variables

| Variable | Typ | Standard | Beschreibung |
|----------|-----|---------|-------------|
| `namespace` | string | `monitoring` | Kubernetes Namespace |
| `enabled` | bool | `true` | Stack aktivieren/deaktivieren |
| `chart_version` | string | `25.3.1` | kube-prometheus-stack Chart Version |
| `prometheus_replica_count` | number | `1` | Prometheus Pod Replicas (1-5) |
| `retention_days` | number | `15` | Metriken-Aufbewahrung in Tagen (1-365) |
| `storage_size` | string | `10Gi` | Persistent Volume Größe |
| `storage_class` | string | `gp2` | Kubernetes Storage Class |
| `prometheus_resources` | object | - | CPU/Memory Requests und Limits |
| `scrape_interval` | number | `30` | Scrape Interval in Sekunden (5-300) |
| `evaluation_interval` | number | `30` | Alert Evaluation Interval in Sekunden |
| `node_exporter_enabled` | bool | `true` | Node Exporter aktivieren |
| `kube_state_metrics_enabled` | bool | `true` | kube-state-metrics aktivieren |
| `alertmanager_enabled` | bool | `true` | Alertmanager aktivieren |
| `grafana_enabled` | bool | `true` | Grafana aktivieren |
| `grafana_admin_password` | string | - | Grafana Admin Password (auto-generated wenn leer) |
| `external_labels` | map | - | Externe Labels für alle Metriken |
| `tags` | map | - | Kubernetes Labels |

## Outputs

| Output | Beschreibung |
|--------|------------|
| `namespace` | Kubernetes Namespace des Monitoring Stacks |
| `prometheus_endpoint` | Prometheus Service FQDN |
| `prometheus_url` | HTTP URL für Prometheus |
| `grafana_endpoint` | Grafana Service FQDN |
| `grafana_url` | HTTP URL für Grafana |
| `grafana_admin_password` | Grafana Admin Password |
| `alertmanager_endpoint` | Alertmanager Service FQDN |
| `alertmanager_url` | HTTP URL für Alertmanager |
| `deployment_info` | Zusammenfassung der Deployment-Konfiguration |

## Zugriff auf die Services

### Von innerhalb des Clusters

```bash
# Prometheus
curl http://kube-prometheus-stack.monitoring.svc.cluster.local:9090

# Grafana (Standard Login: admin / <password>)
curl http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local

# Alertmanager
curl http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093
```

### Port-Forwarding (Local Development)

```bash
# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

## Konfiguration der Scrape Targets

### RabbitMQ Metriken

Das Modul konfiguriert automatisch RabbitMQ Scraping:

```yaml
# RabbitMQ Prometheus Plugin (Port 15692)
- job_name: 'rabbitmq'
  static_configs:
    - targets: ['rabbitmq-headless.rabbitmq.svc.cluster.local:15692']
```

### Custom Pod Annotations

Prometheus sucht nach Pods mit folgenden Annotations:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/metrics"        # Optional (default: /metrics)
  prometheus.io/port: "8080"            # Optional (default: 8080)
```

## Alert Rules Anpassen

Alert Rules sind als Kubernetes CRD `PrometheusRule` definiert in:
- `main.tf`: `kubernetes_manifest.prometheus_rules` Resource

Zum Hinzufügen neuer Alert Rules:

1. Bearbeite `kubernetes_manifest.prometheus_rules` in `main.tf`
2. Füge neue Rule zur `groups` Liste hinzu
3. Format: [Prometheus Alert Syntax](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

## Alertmanager Konfiguration

Alertmanager wird mit Standard-Konfiguration ausgerollt. Zum Anpassen der Notifications:

1. Erstelle Secret mit Alertmanager Config: `kubectl create secret generic alertmanager-config --from-file=alertmanager.yaml -n monitoring`
2. Update Helm Values für Alertmanager
3. Unterstützte Channels: Slack, Email, PagerDuty, Webhook, etc.

## Grafana Datasources und Dashboards

Grafana wird mit Prometheus als DataSource vorkonfiguriert.

### Hinzufügen Custom Dashboards

```bash
# Grafana UI: http://localhost:3000/
# 1. Login mit admin / <password>
# 2. + Neue DataSource: Prometheus auf http://kube-prometheus-stack.monitoring.svc.cluster.local:9090
# 3. + Neues Dashboard: Dashboard JSON importieren
```

Beliebte vordefinierte Dashboards von Grafana Labs:
- [Prometheus 2.0 Overview](https://grafana.com/grafana/dashboards/3662)
- [Kubernetes Cluster Monitoring](https://grafana.com/grafana/dashboards/7249)
- [RabbitMQ Overview](https://grafana.com/grafana/dashboards/10991)

## PromQL Query Examples

```promql
# Node CPU Auslastung
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node Memory Nutzung
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes

# RabbitMQ Queue Größe
rabbitmq_queue_messages_ready{queue!=""}

# Pod CPU Nutzung
sum by (pod_name) (rate(container_cpu_usage_seconds_total[5m]))

# Pod Memory Nutzung
sum by (pod_name) (container_memory_usage_bytes) / 1024 / 1024
```

## Troubleshooting

### Prometheus scrapet RabbitMQ nicht

```bash
# Check RabbitMQ Service
kubectl get svc -n rabbitmq

# Check RabbitMQ Prometheus Port
kubectl exec -it -n rabbitmq <pod> -- nc -zv rabbitmq-headless 15692

# Check Prometheus Config
kubectl logs -n monitoring <prometheus-pod> | grep rabbitmq
```

### Grafana Passwort zurücksetzen

```bash
# Default Admin Credentials (wenn nicht überschrieben)
# Username: admin
# Password: <grafana_admin_password Output>

# Oder über Secret aktualisieren
kubectl patch secret grafana -n monitoring \
  -p '{"data":{"admin-password":"'$(echo -n 'newpassword' | base64)'"}}'
```

### Alert Rules nicht sichtbar

```bash
# Check PrometheusRule CRD
kubectl get prometheusrules -n monitoring

# Check Prometheus Service Monitor
kubectl get servicemonitors -n monitoring

# Check Prometheus Logs
kubectl logs -n monitoring <prometheus-pod> | grep "rule"
```

## Weitere Ressourcen

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards Library](https://grafana.com/grafana/dashboards)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
