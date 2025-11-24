# ============================================================================
# Prometheus Stack Helm Module - Resource Definitions
# ============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Generate random Grafana admin password if not provided
resource "random_password" "grafana_admin_password" {
  count  = var.enabled && var.grafana_admin_password == "" ? 1 : 0
  length = 16
  special = true
}

# Create namespace if not exists
resource "kubernetes_namespace" "monitoring" {
  count = var.enabled ? 1 : 0

  metadata {
    name = var.namespace

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "monitoring"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }
}

# Deploy kube-prometheus-stack using Helm chart
resource "helm_release" "kube_prometheus_stack" {
  count = var.enabled ? 1 : 0

  name             = "kube-prometheus-stack"
  namespace        = kubernetes_namespace.monitoring[0].metadata[0].name
  repository       = var.helm_repository_url
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  create_namespace = false

  wait    = true
  timeout = 600

  # ========================================================================
  # Prometheus Server Configuration
  # ========================================================================
  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.prometheusSpec.replicas"
    value = var.prometheus_replica_count
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.retention_days}d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.storage_size
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.storage_class
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = var.prometheus_resources.requests.cpu
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = var.prometheus_resources.requests.memory
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = var.prometheus_resources.limits.cpu
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = var.prometheus_resources.limits.memory
  }

  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = "${var.scrape_interval}s"
  }

  set {
    name  = "prometheus.prometheusSpec.evaluationInterval"
    value = "${var.evaluation_interval}s"
  }

  # External labels
  set {
    name  = "prometheus.prometheusSpec.externalLabels.cluster"
    value = var.external_labels.cluster
  }

  set {
    name  = "prometheus.prometheusSpec.externalLabels.environment"
    value = "development"
  }

  # Service configuration
  set {
    name  = "prometheus.service.type"
    value = var.service_type
  }

  # Enable service monitors discovery
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Enable pod monitors discovery
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Enable rule discovery
  set {
    name  = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues"
    value = "false"
  }

  # ========================================================================
  # Grafana Configuration
  # ========================================================================
  set {
    name  = "grafana.enabled"
    value = var.grafana_enabled
  }

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_admin_password[0].result
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  # ========================================================================
  # Alertmanager Configuration
  # ========================================================================
  set {
    name  = "alertmanager.enabled"
    value = var.alertmanager_enabled
  }

  set {
    name  = "alertmanager.alertmanagerSpec.replicas"
    value = "1"
  }

  set {
    name  = "alertmanager.config.route.group_by"
    value = "{alertname,cluster,service}"
  }

  set {
    name  = "alertmanager.config.route.group_wait"
    value = "30s"
  }

  set {
    name  = "alertmanager.config.route.group_interval"
    value = "5m"
  }

  set {
    name  = "alertmanager.config.route.repeat_interval"
    value = "12h"
  }

  # ========================================================================
  # Node Exporter Configuration
  # ========================================================================
  set {
    name  = "nodeExporter.enabled"
    value = var.node_exporter_enabled
  }

  # ========================================================================
  # Kube State Metrics Configuration
  # ========================================================================
  set {
    name  = "kubeStateMetrics.enabled"
    value = var.kube_state_metrics_enabled
  }

  # ========================================================================
  # Prometheus Operator Configuration
  # ========================================================================
  set {
    name  = "prometheusOperator.enabled"
    value = var.prometheus_operator_enabled
  }

  # ========================================================================
  # Prometheus Node Ports (if needed for debugging)
  # ========================================================================
  # Uncomment if you want to expose Prometheus via NodePort
  # set {
  #   name  = "prometheus.service.nodePort"
  #   value = "30090"
  # }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

# ============================================================================
# Prometheus Additional Scrape Configs - ConfigMap
# ============================================================================

resource "kubernetes_config_map" "prometheus_scrape_configs" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "prometheus-scrape-configs"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "prometheus"
        "app.kubernetes.io/component"  = "scrape-configs"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  data = {
    "additional-scrape-configs.yaml" = templatefile(
      "${path.module}/additional-scrape-configs.yaml",
      {}
    )
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ============================================================================
# Prometheus Alert Rules - PrometheusRule CRD
# ============================================================================

resource "kubernetes_manifest" "prometheus_rules" {
  count = var.enabled && var.prometheus_operator_enabled ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "eshop-alerts"
      namespace = kubernetes_namespace.monitoring[0].metadata[0].name

      labels = merge(
        var.tags,
        {
          "app.kubernetes.io/name"      = "prometheus"
          "prometheus"                  = helm_release.kube_prometheus_stack[0].name
          "app.kubernetes.io/managed-by" = "terraform"
        }
      )
    }

    spec = {
      groups = [
        {
          name     = "kubernetes.rules"
          interval = "30s"
          rules = [
            {
              alert = "KubernetesPodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total[15m]) > 0.1"
              for   = "5m"
              labels = {
                severity  = "critical"
                component = "kubernetes"
              }
              annotations = {
                summary     = "Kubernetes pod crash looping (instance {{ $labels.namespace }}/{{ $labels.pod }})"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
              }
            },
            {
              alert = "KubernetesPodNotHealthy"
              expr  = "kube_pod_status_phase{phase=~\"Pending|Unknown|Failed\"} == 1"
              for   = "15m"
              labels = {
                severity  = "warning"
                component = "kubernetes"
              }
              annotations = {
                summary     = "Kubernetes Pod not healthy (instance {{ $labels.namespace }}/{{ $labels.pod }})"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for more than 15 minutes."
              }
            },
            {
              alert = "KubernetesNodeNotReady"
              expr  = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
              for   = "5m"
              labels = {
                severity  = "critical"
                component = "kubernetes"
              }
              annotations = {
                summary     = "Kubernetes Node not ready (instance {{ $labels.node }})"
                description = "Node {{ $labels.node }} has been unready for a long time"
              }
            }
          ]
        },
        {
          name     = "rabbitmq.rules"
          interval = "30s"
          rules = [
            {
              alert = "RabbitMQDown"
              expr  = "rabbitmq_up == 0"
              for   = "5m"
              labels = {
                severity  = "critical"
                component = "rabbitmq"
              }
              annotations = {
                summary     = "RabbitMQ is down (instance {{ $labels.instance }})"
                description = "RabbitMQ instance {{ $labels.instance }} is down"
              }
            },
            {
              alert = "RabbitMQMemoryHigh"
              expr  = "rabbitmq_process_resident_memory_bytes / rabbitmq_resident_memory_limit_bytes > 0.9"
              for   = "5m"
              labels = {
                severity  = "warning"
                component = "rabbitmq"
              }
              annotations = {
                summary     = "RabbitMQ memory usage is high (instance {{ $labels.instance }})"
                description = "RabbitMQ instance {{ $labels.instance }} memory usage is above 90%"
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ============================================================================
# Grafana Dashboards - ConfigMaps
# ============================================================================

# Create ConfigMaps for each Grafana dashboard
resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = var.enabled ? fileset("${path.module}/dashboards", "*.json") : toset([])

  metadata {
    name      = "grafana-dashboard-${replace(each.key, ".json", "")}"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "grafana"
        "app.kubernetes.io/component"  = "dashboard"
        "grafana_dashboard"            = "1"  # Tell Grafana to load this ConfigMap
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  data = {
    "${each.key}" = file("${path.module}/dashboards/${each.key}")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ============================================================================
# Alertmanager Email Configuration - ConfigMap
# ============================================================================

resource "kubernetes_config_map" "alertmanager_email_config" {
  count = var.enabled && var.alertmanager_enabled ? 1 : 0

  metadata {
    name      = "alertmanager-email-config"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "alertmanager"
        "app.kubernetes.io/component"  = "config"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  data = {
    "alertmanager-email-config.yaml" = templatefile(
      "${path.module}/alertmanager-email-config.yaml",
      {
        smtp_host     = var.alertmanager_smtp_host
        smtp_port     = var.alertmanager_smtp_port
        smtp_user     = var.alertmanager_smtp_user
        smtp_password = var.alertmanager_smtp_password
        email_from    = var.alertmanager_email_from
        email_to      = var.alertmanager_email_to[0]  # Use first email as primary
      }
    )
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ============================================================================
# Local Computed Values
# ============================================================================

locals {
  prometheus_endpoint      = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
  grafana_endpoint         = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-grafana.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
  alertmanager_endpoint    = var.enabled ? "${helm_release.kube_prometheus_stack[0].name}-alertmanager.${kubernetes_namespace.monitoring[0].metadata[0].name}.svc.cluster.local" : null
  grafana_admin_password   = var.enabled && var.grafana_admin_password != "" ? var.grafana_admin_password : (var.enabled ? random_password.grafana_admin_password[0].result : null)
}
