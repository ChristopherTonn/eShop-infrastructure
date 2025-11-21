# ============================================================================
# RabbitMQ Helm Module - Resource Definitions
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
  }
}

# Create namespace if not exists
resource "kubernetes_namespace" "rabbitmq" {
  count = var.enabled ? 1 : 0

  metadata {
    name = var.namespace

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name"       = "rabbitmq"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }
}

# Create secret for RabbitMQ credentials (if password provided)
resource "kubernetes_secret" "rabbitmq_credentials" {
  count = var.enabled && var.rabbitmq_password != "" ? 1 : 0

  metadata {
    name      = "rabbitmq-credentials"
    namespace = kubernetes_namespace.rabbitmq[0].metadata[0].name

    labels = merge(
      var.tags,
      {
        "app.kubernetes.io/name" = "rabbitmq"
      }
    )
  }

  type = "Opaque"

  data = {
    username = base64encode(var.rabbitmq_username)
    password = base64encode(var.rabbitmq_password)
  }
}

# Add Bitnami Helm repository
# Note: helm_repository resource is deprecated. Repository is added via helm release directly.
# resource "helm_repository" "bitnami" {
#   count = var.enabled ? 1 : 0
#
#   name           = "bitnami"
#   repository_url = var.helm_repository_url
# }

# Deploy RabbitMQ using Helm chart
resource "helm_release" "rabbitmq" {
  count = var.enabled ? 1 : 0

  name       = "rabbitmq"
  namespace  = kubernetes_namespace.rabbitmq[0].metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "rabbitmq"
  version    = var.chart_version

  # Wait for deployment to be ready
  wait             = true
  timeout          = 600
  create_namespace = false

  # RabbitMQ Configuration
  set {
    name  = "auth.username"
    value = var.rabbitmq_username
  }

  set_sensitive {
    name  = "auth.password"
    value = var.rabbitmq_password
  }

  # If erlang cookie is provided
  dynamic "set_sensitive" {
    for_each = var.erlang_cookie != "" ? [var.erlang_cookie] : []
    content {
      name  = "auth.erlangCookie"
      value = set_sensitive.value
    }
  }

  # Replica Configuration
  set {
    name  = "replicaCount"
    value = var.replica_count
  }

  # Persistence Configuration
  set {
    name  = "persistence.enabled"
    value = var.persistence_enabled
  }

  set {
    name  = "persistence.size"
    value = var.storage_size
  }

  set {
    name  = "persistence.storageClass"
    value = var.storage_class
  }

  # Image Configuration
  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  # Service Configuration
  set {
    name  = "service.type"
    value = var.service_type
  }

  set {
    name  = "service.port"
    value = var.amqp_port
  }

  set {
    name  = "service.managementPort"
    value = var.management_ui_port
  }

  # Resource Configuration
  set {
    name  = "resources.requests.cpu"
    value = var.resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.resources.requests.memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.resources.limits.memory
  }

  # Management UI Configuration
  set {
    name  = "managementPlugin.enabled"
    value = var.management_ui_enabled
  }

  # Metrics Configuration
  dynamic "set" {
    for_each = var.metrics_enabled ? [1] : []
    content {
      name  = "metrics.enabled"
      value = true
    }
  }

  # Additional plugins
  set {
    name  = "extraPlugins"
    value = join(" ", var.extra_plugins)
  }

  # Queue master location policy
  set {
    name  = "clustering.queueMasterLocation"
    value = var.queue_master_location
  }

  # Memory high watermark
  set {
    name  = "memoryHighWatermark.enabled"
    value = true
  }

  set {
    name  = "memoryHighWatermark.threshold"
    value = var.memory_high_watermark
  }

  # Node selector
  dynamic "set" {
    for_each = var.node_selector
    content {
      name  = "nodeSelector.${set.key}"
      value = set.value
    }
  }

  # Tolerations
  set {
    name  = "tolerations"
    value = jsonencode(var.tolerations)
  }

  # Affinity
  dynamic "set" {
    for_each = length(var.affinity) > 0 ? [var.affinity] : []
    content {
      name  = "affinity"
      value = jsonencode(set.value)
    }
  }

  # Labels
  set {
    name  = "commonLabels"
    value = jsonencode(merge(var.tags, { "app.kubernetes.io/name" = "rabbitmq" }))
  }

  # Environment variables
  dynamic "set" {
    for_each = var.environment_variables
    content {
      name  = "env.${set.key}"
      value = set.value
    }
  }

  # Security context
  set {
    name  = "podSecurityContext.enabled"
    value = true
  }

  set {
    name  = "podSecurityContext.fsGroup"
    value = 1001
  }

  set {
    name  = "containerSecurityContext.enabled"
    value = true
  }

  set {
    name  = "containerSecurityContext.runAsUser"
    value = 1001
  }

  set {
    name  = "containerSecurityContext.runAsNonRoot"
    value = true
  }

  # Liveness and readiness probes
  set {
    name  = "livenessProbe.enabled"
    value = true
  }

  set {
    name  = "livenessProbe.initialDelaySeconds"
    value = 120
  }

  set {
    name  = "livenessProbe.periodSeconds"
    value = 30
  }

  set {
    name  = "readinessProbe.enabled"
    value = true
  }

  set {
    name  = "readinessProbe.initialDelaySeconds"
    value = 10
  }

  set {
    name  = "readinessProbe.periodSeconds"
    value = 10
  }

  depends_on = [
    kubernetes_namespace.rabbitmq,
    kubernetes_secret.rabbitmq_credentials
  ]
}

# Provide human-readable connection string
locals {
  connection_string = var.enabled ? "amqp://${var.rabbitmq_username}:${var.rabbitmq_password}@rabbitmq.${kubernetes_namespace.rabbitmq[0].metadata[0].name}.svc.cluster.local:${var.amqp_port}/" : ""
}
