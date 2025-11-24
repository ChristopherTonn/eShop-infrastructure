# ============================================================================
# Prometheus Stack Helm Module - Output Values
# ============================================================================

output "namespace" {
  description = "Kubernetes namespace where monitoring stack is deployed"
  value       = var.enabled ? kubernetes_namespace.monitoring[0].metadata[0].name : null
}

output "release_name" {
  description = "Helm release name for kube-prometheus-stack"
  value       = var.enabled ? helm_release.kube_prometheus_stack[0].name : null
}

output "prometheus_endpoint" {
  description = "Prometheus server endpoint (ClusterIP)"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "prometheus_port" {
  description = "Prometheus server port"
  value       = 9090
}

output "prometheus_url" {
  description = "Full URL to access Prometheus"
  value       = var.enabled ? "http://${helm_release.kube_prometheus_stack[0].name}.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:9090" : null
}

output "prometheus_service_fqdn" {
  description = "Fully qualified domain name for Prometheus service"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "grafana_endpoint" {
  description = "Grafana server endpoint (ClusterIP)"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "grafana_port" {
  description = "Grafana server port"
  value       = 80
}

output "grafana_url" {
  description = "Full URL to access Grafana"
  value       = var.enabled ? "http://${helm_release.kube_prometheus_stack[0].name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "grafana_service_fqdn" {
  description = "Fully qualified domain name for Grafana service"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.enabled ? local.grafana_admin_password : null
  sensitive   = true
}

output "alertmanager_endpoint" {
  description = "Alertmanager server endpoint (ClusterIP)"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "alertmanager_port" {
  description = "Alertmanager server port"
  value       = 9093
}

output "alertmanager_url" {
  description = "Full URL to access Alertmanager"
  value       = var.enabled ? "http://${helm_release.kube_prometheus_stack[0].name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local:9093" : null
}

output "alertmanager_service_fqdn" {
  description = "Fully qualified domain name for Alertmanager service"
  value       = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
}

output "enabled" {
  description = "Whether monitoring stack is enabled"
  value       = var.enabled
}

output "chart_version" {
  description = "Version of kube-prometheus-stack Helm chart deployed"
  value       = var.enabled ? var.chart_version : null
}

output "prometheus_storage_size" {
  description = "Prometheus persistent volume size"
  value       = var.enabled ? var.storage_size : null
}

output "prometheus_retention_days" {
  description = "Prometheus data retention period in days"
  value       = var.enabled ? var.retention_days : null
}

output "node_exporter_enabled" {
  description = "Whether Node Exporter is enabled"
  value       = var.node_exporter_enabled
}

output "kube_state_metrics_enabled" {
  description = "Whether kube-state-metrics is enabled"
  value       = var.kube_state_metrics_enabled
}

output "prometheus_operator_enabled" {
  description = "Whether Prometheus Operator is enabled"
  value       = var.prometheus_operator_enabled
}

output "alertmanager_enabled" {
  description = "Whether Alertmanager is enabled"
  value       = var.alertmanager_enabled
}

output "grafana_enabled" {
  description = "Whether Grafana is enabled"
  value       = var.grafana_enabled
}

output "pod_selector_labels" {
  description = "Pod selector labels for Prometheus pods"
  value = var.enabled ? {
    "app.kubernetes.io/name" = "kube-prometheus-stack"
    "prometheus"             = helm_release.kube_prometheus_stack[0].name
  } : {}
}

output "deployment_info" {
  description = "Summary of monitoring stack deployment configuration"
  value = var.enabled ? {
    namespace                      = kubernetes_namespace.monitoring[0].metadata[0].name
    prometheus_replicas            = var.prometheus_replica_count
    prometheus_service_fqdn        = "${helm_release.kube_prometheus_stack[0].name}.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local"
    prometheus_port                = 9090
    grafana_service_fqdn           = "${helm_release.kube_prometheus_stack[0].name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local"
    grafana_port                   = 80
    alertmanager_service_fqdn      = "${helm_release.kube_prometheus_stack[0].name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local"
    alertmanager_port              = 9093
    storage_size                   = var.storage_size
    retention_days                 = var.retention_days
    scrape_interval_seconds        = var.scrape_interval
    evaluation_interval_seconds    = var.evaluation_interval
    node_exporter_enabled          = var.node_exporter_enabled
    kube_state_metrics_enabled     = var.kube_state_metrics_enabled
    prometheus_operator_enabled    = var.prometheus_operator_enabled
    alertmanager_enabled           = var.alertmanager_enabled
    grafana_enabled                = var.grafana_enabled
    chart_version                  = var.chart_version
  } : null
}

output "helm_status" {
  description = "Status of Helm release"
  value       = var.enabled ? helm_release.kube_prometheus_stack[0].status : null
}
