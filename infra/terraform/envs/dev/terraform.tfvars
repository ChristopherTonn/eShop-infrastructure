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

# EKS Cluster Configuration
eks_cluster_version     = "1.28"
eks_node_instance_types = ["t3.medium"]
eks_min_size            = 1
eks_max_size            = 5
eks_desired_size        = 2

# VPC Configuration
vpc_enable_vpc_flow_logs = false # Disabled for dev to save costs

# RDS Configuration
rds_engine_version                        = "15.3"
rds_master_username                       = "postgres"
rds_master_password                       = "DevPassword123!@#" # Change this to strong password in production
rds_backup_retention_period               = 7
rds_allocated_storage                     = 20
rds_max_allocated_storage                 = 100
rds_parameter_group_family                = "postgres15"
rds_storage_type                          = "gp3"
rds_multi_az                              = false
rds_enable_performance_insights           = true
rds_performance_insights_retention_period = 7
rds_enable_enhanced_monitoring            = true
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

# Feature Flags
enable_monitoring = false # Disabled for dev to save costs
enable_backup     = false
enable_multi_az   = false
