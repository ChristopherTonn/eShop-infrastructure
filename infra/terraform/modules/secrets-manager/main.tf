# ============================================================================
# AWS Secrets Manager Module - Resource Definitions
# ============================================================================
# Manages application secrets for the eShop services
# Stores database credentials, API keys, and other sensitive data

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
