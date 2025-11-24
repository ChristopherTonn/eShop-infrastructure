output "log_group_names" {
  description = "Map of service log group names"
  value = {
    for service, lg in aws_cloudwatch_log_group.service_logs : service => lg.name
  }
}

output "log_group_arns" {
  description = "Map of service log group ARNs"
  value = {
    for service, lg in aws_cloudwatch_log_group.service_logs : service => lg.arn
  }
}

output "platform_log_group_name" {
  description = "Platform/system log group name"
  value       = aws_cloudwatch_log_group.platform_logs.name
}

output "platform_log_group_arn" {
  description = "Platform/system log group ARN"
  value       = aws_cloudwatch_log_group.platform_logs.arn
}

output "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit IRSA"
  value       = var.create_fluent_bit_role ? aws_iam_role.fluent_bit[0].arn : null
}

output "fluent_bit_role_name" {
  description = "IAM role name for Fluent Bit IRSA"
  value       = var.create_fluent_bit_role ? aws_iam_role.fluent_bit[0].name : null
}

output "log_retention_days" {
  description = "Default log retention period in days"
  value       = var.log_retention_days
}

output "kms_encryption_enabled" {
  description = "Whether KMS encryption is enabled for CloudWatch Logs"
  value       = var.enable_kms_encryption
}

output "deployment_info" {
  description = "Summary of CloudWatch Logs deployment configuration"
  value = {
    cluster_name         = var.cluster_name
    environment          = var.environment
    region               = var.region
    base_log_group_path  = local.base_log_group_name
    log_groups_count     = length(aws_cloudwatch_log_group.service_logs)
    retention_days       = var.log_retention_days
    kms_encryption       = var.enable_kms_encryption
    fluent_bit_role_arn  = var.create_fluent_bit_role ? aws_iam_role.fluent_bit[0].arn : "not-created"
    oidc_provider        = var.oidc_provider_arn
  }
}
