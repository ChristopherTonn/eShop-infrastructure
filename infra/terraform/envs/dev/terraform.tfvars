# ============================================================================
# Development Environment - Terraform Variables
# ============================================================================
# Variable values for Dev environment deployment

# AWS & Project Configuration
aws_region   = "eu-central-1"
project_name = "eshop"

# Common Tags
common_tags = {
  Project     = "eShop"
  Environment = "development"
  Terraform   = "true"
  ManagedBy   = "Terraform"
  CostCenter  = "dev-ops"
  Owner       = "Platform Team"
  CreatedAt   = "2025-11-21"
}

# Availability Zones
availability_zones = ["eu-central-1a", "eu-central-1b"]

# EKS Cluster Configuration - OPTIMIZED FOR TESTING
eks_cluster_version     = "1.28"
eks_node_instance_types = ["t3.medium"]
eks_min_size            = 1
eks_max_size            = 2  # Reduced for test
eks_desired_size        = 1  # Single node for test (saves ~$0.05/h)

# VPC Configuration
vpc_enable_vpc_flow_logs = false # Disabled for dev to save costs

# RDS Configuration - OPTIMIZED FOR TESTING
rds_engine_version                        = "15.3"
rds_master_username                       = "postgres"
rds_master_password                       = "DevPassword123!@#" # Change this to strong password in production
rds_backup_retention_period               = 1  # Minimal: 1 day only (saves ~$2/day)
rds_allocated_storage                     = 20
rds_max_allocated_storage                 = 100
rds_parameter_group_family                = "postgres15"
rds_storage_type                          = "gp3"
rds_multi_az                              = false
rds_enable_performance_insights           = false  # Disabled for test (saves ~$5/day)
rds_performance_insights_retention_period = 7
rds_enable_enhanced_monitoring            = false  # Disabled for test (saves ~$1/day)
rds_monitoring_interval                   = 60

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
rabbitmq_enabled       = true
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

# Feature Flags - OPTIMIZED FOR TESTING (cost reduction)
enable_monitoring = false # Disabled for test
enable_backup     = false # Disabled for test
enable_multi_az   = false # Single AZ for test

# Monitoring Stack Configuration
monitoring_enabled                    = false  # Disable Prometheus/Grafana (saves ~$25/h)
alertmanager_enabled                  = false  # Disable alerts
grafana_enabled                       = false  # Disable dashboards
prometheus_replica_count              = 1
prometheus_retention_days             = 1      # Minimal retention
node_exporter_enabled                 = false  # Disable node metrics (saves ~$3/h)
kube_state_metrics_enabled            = false  # Disable k8s metrics (saves ~$2/h)

# Logging Configuration
logging_enabled                           = false  # Disable CloudWatch logs (saves ~$10/h)
fluent_bit_enabled                       = false  # Disable log forwarding
cloudwatch_log_retention_days             = 1      # Minimal if enabled
fluent_bit_enable_container_insights     = false  # Disable Container Insights
fluent_bit_enable_multiline_parsing      = false

# Backup Configuration - OPTIMIZED FOR TESTING
rds_skip_final_snapshot = true # Skip final snapshot (ephemeral test environment)

# COST SUMMARY FOR THIS TEST:
# EKS (1 t3.medium): ~$0.033/h
# RDS (db.t3.micro, no backups): ~$0.005/h
# ElastiCache (cache.t3.micro): ~$0.007/h
# ALB + NAT: ~$0.020/h
# TOTAL: ~$0.065/h = ~$1.56/day = ~$7.80 for 5-day test
