# ============================================================================
# RDS Module - Outputs
# ============================================================================

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Database master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "db_subnet_group_id" {
  description = "DB subnet group ID"
  value       = aws_db_subnet_group.main.id
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.enable_encryption ? aws_kms_key.rds[0].id : null
}

output "secrets_manager_arn" {
  description = "Secrets Manager ARN containing database credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "read_replica_endpoint" {
  description = "Read replica endpoint (production only)"
  value       = var.environment == "prod" ? aws_db_instance.read_replica[0].endpoint : null
  sensitive   = true
}