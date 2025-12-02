# ============================================================================
# Development Environment - Terraform Variables
# ============================================================================
# Variable values for Dev environment deployment

# AWS & Project Configuration
aws_profile  = "eshop-terraform"
aws_region   = "eu-central-1"
project_name = "eshop"

# Common Tags
common_tags = {
  Project     = "eShop"
  Environment = "development"
  Terraform   = "true"
  ManagedBy   = "Terraform"
  CostCenter  = "devops"
  Owner       = "platform-team"
  CreatedAt   = "2025-11-21"
}

# Availability Zones
availability_zones = ["eu-central-1a", "eu-central-1b"]

# EKS Cluster Configuration - OPTIMIZED FOR TESTING
eks_cluster_version     = "1.29"
eks_node_instance_types = ["t3.medium"]
eks_min_size            = 1
eks_max_size            = 2  # Reduced for test
eks_desired_size        = 1  # Single node for test (saves ~$0.05/h)

# VPC Configuration
vpc_enable_vpc_flow_logs = false # Disabled for dev to save costs

# RDS Configuration - OPTIMIZED FOR TESTING
rds_engine_version                        = "15.10"
rds_master_username                       = "postgres"
rds_master_password                       = "DevPassword123!@#" # Change this to strong password in production
rds_backup_retention_period               = 1  # Minimal: 1 day only (saves ~$2/day)
rds_allocated_storage                     = 20

# SMTP Configuration for Alertmanager Email Notifications
alertmanager_smtp_host     = "smtp.gmail.com"
alertmanager_smtp_port     = 587
alertmanager_smtp_user     = "your-email@gmail.com"  # Change to your email
alertmanager_smtp_password = "your-app-password"     # Change to your app password
alertmanager_email_from    = "alerts@eshop.de"
alertmanager_email_to      = ["devops@eshop.de", "christopher.tonn@gmail.com"]

# ElastiCache Configuration
elasticache_engine_version             = "7.0"
elasticache_num_cache_nodes            = 1
elasticache_node_type                  = "cache.t3.micro"
elasticache_parameter_group_family     = "redis7"
elasticache_automatic_failover_enabled = false
elasticache_multi_az_enabled           = false
elasticache_at_rest_encryption_enabled = true
elasticache_transit_encryption_enabled = true
elasticache_auth_token                 = "DevRedisAuth123!@#Dev" # Change this in production

# Secrets Configuration
jwt_signing_secret = "dev-jwt-signing-secret-key-min-32-chars-required-long-string"
rabbitmq_username  = "guest"
rabbitmq_password  = "DevRabbitPassword123!@#"

# RabbitMQ Configuration (Helm)
rabbitmq_enabled       = false  # Disabled - wegen K8s Provider Issue
rabbitmq_chart_version = "13.0.0"
rabbitmq_replica_count = 1 # Dev: single replica
rabbitmq_storage_size  = "5Gi"
rabbitmq_resources = {
  requests = {
    cpu    = "100m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

# Skip K8s CSI Driver for now (depends on K8s Provider)
k8s_csi_driver_enabled = false

# EKS SSH Key for Node Access
eks_node_ssh_key = "eshop-dev-key"

# Feature Flags - OPTIMIZED FOR TESTING (cost reduction)
enable_monitoring = false # Disabled for test
enable_backup     = false # Disabled for test
enable_multi_az   = false # Single AZ for test

# Monitoring Stack Configuration - FULL E2E TESTING
monitoring_enabled                    = false  # Disabled - wegen K8s Provider Issue
alertmanager_enabled                  = false  # Disabled
grafana_enabled                        = false  # Disabled
prometheus_replica_count              = 1
prometheus_retention_days             = 1
node_exporter_enabled                 = false
kube_state_metrics_enabled            = false

# Logging Configuration - FULL E2E TESTING
logging_enabled                           = false  # Disabled - wegen K8s Provider Issue
fluent_bit_enabled                       = false  # Disabled
cloudwatch_log_retention_days             = 1
fluent_bit_enable_container_insights     = false
fluent_bit_enable_multiline_parsing      = true

# Backup Configuration - OPTIMIZED FOR TESTING
rds_skip_final_snapshot = true # Skip final snapshot (ephemeral test environment)

# COST SUMMARY FOR FULL E2E TEST WITH MONITORING, ALERTS & LOGGING:
# EKS (1 t3.medium): ~$0.033/h
# RDS (db.t3.micro, no backups): ~$0.005/h
# ElastiCache (cache.t3.micro): ~$0.007/h
# ALB + NAT: ~$0.020/h
# Prometheus + Grafana: ~$8-10/h
# Alertmanager: ~$0.15/h
# CloudWatch Logs + Fluent Bit: ~$0.70/h
# ─────────────────────────────────
# TOTAL: ~$8.8-10.8/h = ~$211-259/day for comprehensive E2E test
# 5-day test: ~$1055-1295 (validation of complete observability stack)
