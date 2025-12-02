terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

locals {
  merged_tags = merge(
    var.tags,
    {
      Module      = "logging-fluent-bit"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  log_group_prefix = "${var.cloudwatch_log_group_prefix}/${var.cluster_name}"
}

# Create Kubernetes namespace for Fluent Bit
resource "kubernetes_namespace" "logging" {
  metadata {
    name = var.kubernetes_namespace
    labels = {
      "app.kubernetes.io/name"       = "fluent-bit"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [var.depends_on_modules]
}

# ServiceAccount with IRSA annotation for CloudWatch access
resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.logging.metadata[0].name
    annotations = var.fluent_bit_role_arn != "" ? {
      "eks.amazonaws.com/role-arn" = var.fluent_bit_role_arn
    } : {}
  }
}

# Deploy Fluent Bit via Helm
resource "helm_release" "fluent_bit" {
  count      = var.fluent_bit_enabled ? 1 : 0
  name       = "fluent-bit"
  repository = var.fluent_bit_repository
  chart      = "fluent-bit"
  version    = var.fluent_bit_chart_version
  namespace  = kubernetes_namespace.logging.metadata[0].name
  max_history = 10

  values = [
    templatefile("${path.module}/values.yaml", {
      image_repository    = var.fluent_bit_image_repository
      image_tag           = var.fluent_bit_image_tag
      service_account     = kubernetes_service_account.fluent_bit.metadata[0].name
      cpu_requests        = var.fluent_bit_resources.requests.cpu
      memory_requests     = var.fluent_bit_resources.requests.memory
      cpu_limits          = var.fluent_bit_resources.limits.cpu
      memory_limits       = var.fluent_bit_resources.limits.memory
      log_group_prefix    = local.log_group_prefix
      region              = var.region
      enable_insights     = var.enable_container_insights
      multiline_parsing   = var.log_format_multiline
      buffer_size         = var.buffer_size
      cluster_name        = var.cluster_name
    })
  ]

  depends_on = [
    kubernetes_namespace.logging,
    kubernetes_service_account.fluent_bit
  ]
}

# ConfigMap for custom log parsing (additional configuration)
resource "kubernetes_config_map" "fluent_bit_custom" {
  metadata {
    name      = "fluent-bit-custom-parsers"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "custom-parsers.conf" = file("${path.module}/custom-parsers.conf")
  }

  depends_on = [helm_release.fluent_bit]
}
