# ============================================================================
# Development Environment - Input Variables
# ============================================================================

# AWS Configuration
variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "eshop"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "eShop"
    Environment = "development"
    Terraform   = "true"
    ManagedBy   = "Terraform"
  }
}

variable "availability_zones" {
  description = "List of availability zones for resource deployment"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# VPC Configuration
variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

# RDS Configuration
variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.3"
}

variable "rds_master_username" {
  description = "RDS master database username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "rds_master_password" {
  description = "RDS master database password"
  type        = string
  sensitive   = true
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Skip creation of final snapshot when destroying RDS instance"
  type        = bool
  default     = false
}

# ElastiCache Configuration
variable "elasticache_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "elasticache_num_cache_nodes" {
  description = "Number of cache nodes in ElastiCache cluster"
  type        = number
  default     = 1
}

# Secrets Configuration
variable "jwt_signing_secret" {
  description = "JWT signing secret key"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password for authentication"
  type        = string
  sensitive   = true
  default     = ""
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
  description = "Additional API keys to store in Secrets Manager"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "additional_secrets" {
  description = "Additional secrets to store in Secrets Manager"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "secrets_kms_key_id" {
  description = "KMS key ID for Secrets Manager encryption"
  type        = string
  default     = null
}

# RabbitMQ Configuration
variable "rabbitmq_enabled" {
  description = "Enable RabbitMQ Helm deployment"
  type        = bool
  default     = true
}

variable "rabbitmq_chart_version" {
  description = "RabbitMQ Helm chart version"
  type        = string
  default     = "13.0.0"
}

variable "rabbitmq_replica_count" {
  description = "Number of RabbitMQ replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.rabbitmq_replica_count >= 1 && var.rabbitmq_replica_count <= 10
    error_message = "RabbitMQ replica count must be between 1 and 10."
  }
}

variable "rabbitmq_storage_size" {
  description = "RabbitMQ persistent storage size"
  type        = string
  default     = "5Gi"
}

variable "rabbitmq_resources" {
  description = "RabbitMQ pod resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

# ============================================================================
# Monitoring Stack Configuration (Prometheus, Grafana, Alertmanager)
# ============================================================================

variable "monitoring_enabled" {
  description = "Enable monitoring stack (Prometheus, Grafana, Alertmanager)"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "25.3.1"
}

variable "prometheus_replica_count" {
  description = "Number of Prometheus server replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.prometheus_replica_count >= 1 && var.prometheus_replica_count <= 5
    error_message = "Prometheus replica count must be between 1 and 5."
  }
}

variable "prometheus_retention_days" {
  description = "Prometheus metrics retention period in days"
  type        = number
  default     = 15

  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "Retention period must be between 1 and 365 days."
  }
}

variable "prometheus_storage_size" {
  description = "Prometheus persistent volume size"
  type        = string
  default     = "10Gi"
}

variable "prometheus_scrape_interval" {
  description = "Prometheus scrape interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.prometheus_scrape_interval >= 5 && var.prometheus_scrape_interval <= 300
    error_message = "Scrape interval must be between 5 and 300 seconds."
  }
}

variable "prometheus_evaluation_interval" {
  description = "Prometheus evaluation interval for alert rules in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.prometheus_evaluation_interval >= 5 && var.prometheus_evaluation_interval <= 300
    error_message = "Evaluation interval must be between 5 and 300 seconds."
  }
}

variable "prometheus_resources" {
  description = "Prometheus pod resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "node_exporter_enabled" {
  description = "Enable Node Exporter for hardware metrics"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Enable kube-state-metrics for Kubernetes metrics"
  type        = bool
  default     = true
}

variable "alertmanager_enabled" {
  description = "Enable Alertmanager component"
  type        = bool
  default     = true
}

variable "grafana_enabled" {
  description = "Enable Grafana component"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password (randomly generated if not provided)"
  type        = string
  sensitive   = true
  default     = ""
}
