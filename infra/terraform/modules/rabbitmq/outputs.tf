# ============================================================================
# RabbitMQ Helm Module - Output Values
# ============================================================================

output "namespace" {
  description = "Kubernetes namespace where RabbitMQ is deployed"
  value       = var.enabled ? kubernetes_namespace.rabbitmq[0].metadata[0].name : null
}

output "release_name" {
  description = "Helm release name for RabbitMQ"
  value       = var.enabled ? helm_release.rabbitmq[0].name : null
}

output "service_name" {
  description = "Kubernetes service name for RabbitMQ"
  value       = var.enabled ? "${helm_release.rabbitmq[0].name}-headless" : null
}

output "service_fqdn" {
  description = "Fully qualified domain name for RabbitMQ service"
  value       = var.enabled ? "${helm_release.rabbitmq[0].name}-headless.${kubernetes_namespace.rabbitmq[0].metadata[0].name}.svc.cluster.local" : null
}

output "amqp_connection_string" {
  description = "AMQP connection string for RabbitMQ"
  value       = local.connection_string
  sensitive   = true
}

output "amqp_host" {
  description = "AMQP host address for RabbitMQ"
  value       = var.enabled ? "rabbitmq-headless.${kubernetes_namespace.rabbitmq[0].metadata[0].name}.svc.cluster.local" : null
}

output "amqp_port" {
  description = "AMQP port for RabbitMQ"
  value       = var.enabled ? var.amqp_port : null
}

output "management_ui_url" {
  description = "URL for RabbitMQ Management UI (web console)"
  value       = var.enabled && var.management_ui_enabled ? "http://rabbitmq-headless.${kubernetes_namespace.rabbitmq[0].metadata[0].name}.svc.cluster.local:${var.management_ui_port}" : null
}

output "management_ui_port" {
  description = "Management UI port"
  value       = var.enabled ? var.management_ui_port : null
}

output "username" {
  description = "RabbitMQ default username"
  value       = var.rabbitmq_username
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Kubernetes secret name containing RabbitMQ credentials"
  value       = var.enabled && var.rabbitmq_password != "" ? kubernetes_secret.rabbitmq_credentials[0].metadata[0].name : null
}

output "replicas" {
  description = "Number of RabbitMQ replica pods deployed"
  value       = var.enabled ? var.replica_count : null
}

output "statefulset_name" {
  description = "Name of the RabbitMQ StatefulSet"
  value       = var.enabled ? "${helm_release.rabbitmq[0].name}-replica-0" : null
}

output "pod_selector_labels" {
  description = "Pod selector labels for RabbitMQ pods"
  value = var.enabled ? {
    "app.kubernetes.io/instance" = helm_release.rabbitmq[0].name
    "app.kubernetes.io/name"     = "rabbitmq"
  } : {}
}

output "enabled" {
  description = "Whether RabbitMQ deployment is enabled"
  value       = var.enabled
}

output "chart_version" {
  description = "Version of RabbitMQ Helm chart deployed"
  value       = var.enabled ? var.chart_version : null
}

output "storage_size" {
  description = "PVC storage size for RabbitMQ"
  value       = var.enabled ? var.storage_size : null
}

output "resource_requests" {
  description = "Resource requests for RabbitMQ pods"
  value       = var.enabled ? var.resources.requests : null
}

output "resource_limits" {
  description = "Resource limits for RabbitMQ pods"
  value       = var.enabled ? var.resources.limits : null
}

output "helm_status" {
  description = "Status of Helm release"
  value       = var.enabled ? helm_release.rabbitmq[0].status : null
}

output "deployment_info" {
  description = "Summary of RabbitMQ deployment configuration"
  value = var.enabled ? {
    namespace               = kubernetes_namespace.rabbitmq[0].metadata[0].name
    replicas               = var.replica_count
    service_fqdn           = "${helm_release.rabbitmq[0].name}-headless.${kubernetes_namespace.rabbitmq[0].metadata[0].name}.svc.cluster.local"
    amqp_port              = var.amqp_port
    management_ui_enabled  = var.management_ui_enabled
    management_ui_port     = var.management_ui_port
    persistence_enabled    = var.persistence_enabled
    storage_size           = var.storage_size
    image_repository       = var.image_repository
    image_tag              = var.image_tag
    chart_version          = var.chart_version
  } : null
}
