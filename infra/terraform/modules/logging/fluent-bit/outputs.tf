output "fluent_bit_namespace" {
  description = "Kubernetes namespace for Fluent Bit"
  value       = kubernetes_namespace.logging.metadata[0].name
}

output "fluent_bit_service_account" {
  description = "Service account name for Fluent Bit"
  value       = kubernetes_service_account.fluent_bit.metadata[0].name
}

output "fluent_bit_helm_release_name" {
  description = "Helm release name for Fluent Bit"
  value       = var.fluent_bit_enabled ? helm_release.fluent_bit[0].name : null
}

output "fluent_bit_helm_release_status" {
  description = "Status of Fluent Bit Helm release"
  value       = var.fluent_bit_enabled ? helm_release.fluent_bit[0].status : "disabled"
}

output "fluent_bit_chart_version" {
  description = "Fluent Bit Helm chart version deployed"
  value       = var.fluent_bit_chart_version
}

output "deployment_info" {
  description = "Summary of Fluent Bit deployment configuration"
  value = {
    enabled           = var.fluent_bit_enabled
    namespace         = kubernetes_namespace.logging.metadata[0].name
    service_account   = kubernetes_service_account.fluent_bit.metadata[0].name
    cluster_name      = var.cluster_name
    region            = var.region
    log_group_prefix  = local.log_group_prefix
    chart_version     = var.fluent_bit_chart_version
    image_repository  = var.fluent_bit_image_repository
    image_tag         = var.fluent_bit_image_tag
    cpu_requests      = var.fluent_bit_resources.requests.cpu
    memory_requests   = var.fluent_bit_resources.requests.memory
    cpu_limits        = var.fluent_bit_resources.limits.cpu
    memory_limits     = var.fluent_bit_resources.limits.memory
    container_insights = var.enable_container_insights
    multiline_parsing  = var.log_format_multiline
  }
}
