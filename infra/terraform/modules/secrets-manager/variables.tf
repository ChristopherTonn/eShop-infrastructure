# ============================================================================
# AWS Secrets Manager Module
# ============================================================================
# Manages application secrets for the eShop services
# Stores database credentials, API keys, and other sensitive data

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for secret names"
  type        = string
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_secret" {
  description = "JWT signing secret for Identity API"
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ username"
  type        = string
  sensitive   = true
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}

variable "api_keys" {
  description = "API keys for external services"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "additional_secrets" {
  description = "Additional secrets as key-value pairs"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "Optional KMS key ID for encryption (if not provided, AWS managed key is used)"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Number of days for secret recovery window"
  type        = number
  default     = 30
  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

# ============================================================================
# RDS Credentials Secret
# ============================================================================

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.name_prefix}/rds/credentials"
  description             = "RDS database credentials for ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.rds_username
    password = var.rds_password
  })
}

# ============================================================================
# Redis/ElastiCache Credentials Secret
# ============================================================================

resource "aws_secretsmanager_secret" "redis_credentials" {
  count                   = var.redis_password != "" ? 1 : 0
  name                    = "${var.name_prefix}/redis/credentials"
  description             = "Redis/ElastiCache password for ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  count          = var.redis_password != "" ? 1 : 0
  secret_id      = aws_secretsmanager_secret.redis_credentials[0].id
  secret_string  = var.redis_password
}

# ============================================================================
# JWT Secret
# ============================================================================

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.name_prefix}/identity/jwt-secret"
  description             = "JWT signing secret for Identity API in ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jwt-secret"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

# ============================================================================
# RabbitMQ Credentials Secret
# ============================================================================

resource "aws_secretsmanager_secret" "rabbitmq_credentials" {
  name                    = "${var.name_prefix}/rabbitmq/credentials"
  description             = "RabbitMQ credentials for ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rabbitmq-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "rabbitmq_credentials" {
  secret_id = aws_secretsmanager_secret.rabbitmq_credentials.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = var.rabbitmq_password
  })
}

# ============================================================================
# API Keys Secret
# ============================================================================

resource "aws_secretsmanager_secret" "api_keys" {
  count                   = length(var.api_keys) > 0 ? 1 : 0
  name                    = "${var.name_prefix}/api-keys"
  description             = "External API keys for ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-keys"
  })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  count          = length(var.api_keys) > 0 ? 1 : 0
  secret_id      = aws_secretsmanager_secret.api_keys[0].id
  secret_string  = jsonencode(var.api_keys)
}

# ============================================================================
# Additional Secrets
# ============================================================================

resource "aws_secretsmanager_secret" "additional" {
  for_each                = var.additional_secrets
  name                    = "${var.name_prefix}/app/${each.key}"
  description             = "Application secret: ${each.key} for ${var.environment}"
  kms_key_id             = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

resource "aws_secretsmanager_secret_version" "additional" {
  for_each      = var.additional_secrets
  secret_id     = aws_secretsmanager_secret.additional[each.key].id
  secret_string = each.value
}

# ============================================================================
# Outputs
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
