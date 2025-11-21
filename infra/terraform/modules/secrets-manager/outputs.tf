# ============================================================================
# AWS Secrets Manager Module - Outputs
# ============================================================================

output "rds_secret_arn" {
  description = "ARN of RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_secret_name" {
  description = "Name of RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

output "redis_secret_arn" {
  description = "ARN of Redis credentials secret"
  value       = try(aws_secretsmanager_secret.redis_credentials[0].arn, null)
}

output "redis_secret_name" {
  description = "Name of Redis credentials secret"
  value       = try(aws_secretsmanager_secret.redis_credentials[0].name, null)
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Name of JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "rabbitmq_secret_arn" {
  description = "ARN of RabbitMQ credentials secret"
  value       = aws_secretsmanager_secret.rabbitmq_credentials.arn
}

output "rabbitmq_secret_name" {
  description = "Name of RabbitMQ credentials secret"
  value       = aws_secretsmanager_secret.rabbitmq_credentials.name
}

output "api_keys_secret_arn" {
  description = "ARN of API keys secret"
  value       = try(aws_secretsmanager_secret.api_keys[0].arn, null)
}

output "api_keys_secret_name" {
  description = "Name of API keys secret"
  value       = try(aws_secretsmanager_secret.api_keys[0].name, null)
}

output "additional_secrets_arns" {
  description = "ARNs of additional secrets"
  value       = { for k, v in aws_secretsmanager_secret.additional : k => v.arn }
}

output "all_secret_names" {
  description = "All secret names for reference"
  value = merge(
    {
      rds      = aws_secretsmanager_secret.rds_credentials.name
      jwt      = aws_secretsmanager_secret.jwt_secret.name
      rabbitmq = aws_secretsmanager_secret.rabbitmq_credentials.name
    },
    {
      redis = try(aws_secretsmanager_secret.redis_credentials[0].name, null)
    },
    {
      api_keys = try(aws_secretsmanager_secret.api_keys[0].name, null)
    },
    { for k, v in aws_secretsmanager_secret.additional : k => v.name }
  )
}
