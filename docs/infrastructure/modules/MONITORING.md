# Monitoring Module

Prometheus & Grafana observability stack configuration.

**Navigation:** [← Logging](LOGGING.md) | [Back to Modules Index](../README.md)

---

## 📋 Overview

The Monitoring module deploys Prometheus for metrics collection and Grafana for visualization and dashboarding, providing real-time observability for eShop infrastructure and applications.

**Location:** `infra/terraform/modules/monitoring/`

## 🏗️ Key Resources

- **Prometheus StatefulSet**: Time-series metrics database
- **Prometheus Service**: Metrics API endpoint
- **Grafana Deployment**: Visualization and dashboards
- **Grafana Service**: Web UI access
- **ConfigMaps**: Prometheus scrape configs, alert rules
- **Persistent Volumes**: Data persistence for Prometheus and Grafana
- **ServiceMonitor**: Kubernetes integration for automatic scrape target discovery
- **PrometheusRule**: Alert definitions

## 🔧 Configuration

### Input Variables

See `variables.tf` for:
- `namespace` - Kubernetes namespace for monitoring stack
- `prometheus_storage_size` - Prometheus persistence volume size
- `grafana_admin_password` - Grafana initial password
- `retention_days` - Prometheus metrics retention (e.g., 15)
- `scrape_interval` - Metrics collection interval (e.g., 30s)
- `tags` - Resource tags

### Output Values

See `outputs.tf` for:
- `prometheus_endpoint` - Metrics API URL
- `grafana_url` - Grafana web UI URL
- `grafana_username` / `grafana_password` - Access credentials

## 📚 Related Documentation

- [Terraform Guide](../TERRAFORM_GUIDE.md) - Infrastructure-as-Code setup
- [Monitoring & Alerting](../../runbooks/MONITORING_ALERTS.md) - Metrics and alerting setup
- [CI/CD Documentation](../../CI-CD.md) - Pipeline metrics tracking
- [Infrastructure Overview](../README.md) - Complete infrastructure design

---

**Source Code:** `infra/terraform/modules/monitoring/`

**Last updated:** December 2025
