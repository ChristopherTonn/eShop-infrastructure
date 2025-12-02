# ============================================================================
# ElastiCache Module - Main Configuration
# ============================================================================

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# ============================================================================
# ElastiCache Subnet Group
# ============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-cache-subnet-${data.aws_caller_identity.current.account_id}"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cache-subnet-group"
    Type = "elasticache-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Security Group for ElastiCache
# ============================================================================

resource "aws_security_group" "elasticache" {
  name_prefix = "${var.name_prefix}-elasticache-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-elasticache-sg"
    Type = "security-group"
  })
}

# ============================================================================
# ElastiCache Parameter Group
# ============================================================================

resource "aws_elasticache_parameter_group" "main" {
  family = "redis7"
  name   = "${var.name_prefix}-redis-params-${data.aws_caller_identity.current.account_id}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-params"
    Type = "elasticache-parameter-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# KMS Key for ElastiCache Encryption
# ============================================================================

resource "aws_kms_key" "elasticache" {
  count = var.enable_encryption_at_rest ? 1 : 0

  description             = "KMS key for ElastiCache encryption"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-elasticache-key"
    Type = "kms-key"
  })
}

resource "aws_kms_alias" "elasticache" {
  count = var.enable_encryption_at_rest ? 1 : 0

  name          = "alias/${var.name_prefix}-elasticache"
  target_key_id = aws_kms_key.elasticache[0].key_id
}

# ============================================================================
# ElastiCache Replication Group (Redis Cluster)
# ============================================================================

resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.name_prefix}-redis"
  description                  = "Redis cluster for ${var.name_prefix}"
  
  # Engine configuration
  engine               = "redis"
  engine_version       = var.engine_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main.name
  
  # Node configuration
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled          = var.num_cache_nodes > 1 && var.environment == "prod"
  
  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]
  
  # Encryption
  at_rest_encryption_enabled = var.enable_encryption_at_rest
  transit_encryption_enabled = var.enable_encryption_in_transit
  kms_key_id                 = var.enable_encryption_at_rest ? aws_kms_key.elasticache[0].arn : null
  
  # Auth token for encryption in transit
  auth_token = var.enable_encryption_in_transit ? random_password.auth_token[0].result : null
  
  # Backup configuration
  snapshot_retention_limit = var.enable_backup ? var.backup_retention_limit : 0
  snapshot_window         = var.enable_backup ? var.backup_window : null
  maintenance_window      = var.maintenance_window
  
  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  # Apply changes immediately for non-prod environments
  apply_immediately = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis"
    Type = "elasticache-replication-group"
  })

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# ============================================================================
# Random Auth Token for Encryption in Transit
# ============================================================================

resource "random_password" "auth_token" {
  count = var.enable_encryption_in_transit ? 1 : 0

  length  = 32
  special = false # Auth token doesn't support special characters
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${var.name_prefix}/redis-slow"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-slow-logs"
    Type = "log-group"
  })
}

# ============================================================================
# Secrets Manager for Auth Token
# ============================================================================

resource "aws_secretsmanager_secret" "redis_auth" {
  count = var.enable_encryption_in_transit ? 1 : 0

  name                    = "${var.name_prefix}-redis-auth"
  description             = "Redis auth token"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-auth"
    Type = "secret"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  count = var.enable_encryption_in_transit ? 1 : 0

  secret_id = aws_secretsmanager_secret.redis_auth[0].id
  secret_string = jsonencode({
    auth_token = random_password.auth_token[0].result
    endpoint   = aws_elasticache_replication_group.main.configuration_endpoint_address != "" ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
    port       = 6379
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.name_prefix}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-cpu-alarm"
    Type = "cloudwatch-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "${var.name_prefix}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = [] # Add SNS topic ARN here for notifications

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-memory-alarm"
    Type = "cloudwatch-alarm"
  })
}