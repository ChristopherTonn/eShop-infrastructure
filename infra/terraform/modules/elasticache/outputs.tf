# ============================================================================
# ElastiCache Module - Outputs
# ============================================================================

output "endpoint" {
  description = "ElastiCache endpoint"
  value = aws_elasticache_replication_group.main.configuration_endpoint_address != "" ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "port" {
  description = "ElastiCache port"
  value       = aws_elasticache_replication_group.main.port
}

output "replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.main.id
}

output "replication_group_arn" {
  description = "ElastiCache replication group ARN"
  value       = aws_elasticache_replication_group.main.arn
}

output "primary_endpoint_address" {
  description = "Primary endpoint address"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint address (cluster mode enabled)"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
  sensitive   = true
}

output "security_group_id" {
  description = "ElastiCache security group ID"
  value       = aws_security_group.elasticache.id
}

output "subnet_group_name" {
  description = "ElastiCache subnet group name"
  value       = aws_elasticache_subnet_group.main.name
}

output "parameter_group_name" {
  description = "ElastiCache parameter group name"
  value       = aws_elasticache_parameter_group.main.name
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.enable_encryption_at_rest ? aws_kms_key.elasticache[0].id : null
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN containing auth token"
  value       = var.enable_encryption_in_transit ? aws_secretsmanager_secret.redis_auth[0].arn : null
}