# ============================================================================
# RDS Module - Main Configuration
# ============================================================================

# ============================================================================
# Random Password Generation
# ============================================================================

resource "random_password" "master" {
  length  = 16
  special = true
}

# ============================================================================
# DB Subnet Group
# ============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
    Type = "db-subnet-group"
  })
}

# ============================================================================
# Security Group for RDS
# ============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "PostgreSQL access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
    Type = "security-group"
  })
}

# ============================================================================
# DB Parameter Group
# ============================================================================

resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.name_prefix}-postgres-params"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres-params"
    Type = "db-parameter-group"
  })
}

# ============================================================================
# KMS Key for RDS Encryption
# ============================================================================

resource "aws_kms_key" "rds" {
  count = var.enable_encryption ? 1 : 0

  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-key"
    Type = "kms-key"
  })
}

resource "aws_kms_alias" "rds" {
  count = var.enable_encryption ? 1 : 0

  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

# ============================================================================
# RDS Instance
# ============================================================================

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = var.enable_encryption
  kms_key_id           = var.enable_encryption ? aws_kms_key.rds[0].arn : null

  # Database configuration
  db_name  = "eshop"
  username = "postgres"
  password = random_password.master.result
  port     = 5432

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High availability
  multi_az = var.multi_az

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "Sun:04:00-Sun:05:00"

  # Performance and monitoring
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.enable_performance_insights ? 60 : 0
  monitoring_role_arn         = var.enable_performance_insights ? aws_iam_role.rds_monitoring[0].arn : null

  # Security
  deletion_protection = var.enable_deletion_protection
  
  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Final snapshot
  final_snapshot_identifier = "${var.name_prefix}-postgres-final-snapshot"
  skip_final_snapshot      = false

  # Apply changes immediately for non-prod environments
  apply_immediately = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
    Type = "rds-instance"
  })

  lifecycle {
    ignore_changes = [password]
  }
}

# ============================================================================
# CloudWatch Log Group for RDS
# ============================================================================

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/aws/rds/instance/${aws_db_instance.main.identifier}/postgresql"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres-logs"
    Type = "log-group"
  })
}

# ============================================================================
# IAM Role for RDS Enhanced Monitoring
# ============================================================================

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_performance_insights ? 1 : 0

  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-monitoring-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_performance_insights ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# Secrets Manager for Database Credentials
# ============================================================================

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.name_prefix}-rds-credentials"
  description             = "RDS PostgreSQL credentials"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-credentials"
    Type = "secret"
  })
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ============================================================================
# Read Replica (for production environment)
# ============================================================================

resource "aws_db_instance" "read_replica" {
  count = var.environment == "prod" ? 1 : 0

  identifier = "${var.name_prefix}-postgres-replica"

  # Source configuration
  replicate_source_db = aws_db_instance.main.identifier

  # Instance configuration
  instance_class = var.instance_class

  # Network configuration
  publicly_accessible = false

  # Performance and monitoring
  performance_insights_enabled = var.enable_performance_insights
  monitoring_interval         = var.enable_performance_insights ? 60 : 0
  monitoring_role_arn         = var.enable_performance_insights ? aws_iam_role.rds_monitoring[0].arn : null

  # Apply changes immediately for non-prod environments
  apply_immediately = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres-replica"
    Type = "rds-read-replica"
  })
}