# ============================================================================
# eShop Infrastructure - Development Environment
# ============================================================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Note: Backend configuration requires bootstrap infrastructure (S3 bucket, DynamoDB table)
  # To enable remote state, run bootstrap first: terraform -chdir=../bootstrap apply
  # Then uncomment the backend configuration below
  #
  # backend "s3" {
  #   bucket         = "eshop-terraform-state-dev"
  #   key            = "dev/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "eshop-terraform-lock-dev"
  #   encrypt        = true
  # }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Environment = "development"
      CostCenter  = "dev-ops"
    })
  }
}

provider "kubernetes" {
  # Phase 1: Use try() to handle missing EKS resources gracefully
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
  token                  = try(data.aws_eks_cluster_auth.cluster.token, "")
}

provider "helm" {
  kubernetes {
    # Phase 1: Use try() to handle missing EKS resources gracefully
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
    token                  = try(data.aws_eks_cluster_auth.cluster.token, "")
  }
}

# Get cluster auth token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  environment = "dev"
  name_prefix = "${var.project_name}-${local.environment}"

  # Development-specific overrides
  vpc_cidr = "10.0.0.0/16"

  # Smaller instances for dev
  eks_node_instance_types = ["t3.medium"]
  eks_desired_size        = 2
  eks_min_size            = 1
  eks_max_size            = 5

  rds_instance_class    = "db.t3.micro"
  rds_allocated_storage = 20

  elasticache_node_type = "cache.t3.micro"
}

# ============================================================================
# VPC Module
# ============================================================================

module "vpc" {
  source = "../../modules/vpc"

  environment        = local.environment
  name_prefix        = local.name_prefix
  vpc_cidr           = local.vpc_cidr
  availability_zones = var.availability_zones

  enable_vpc_flow_logs = var.enable_vpc_flow_logs

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# ECR Module
# ============================================================================

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.name_prefix

  repositories = [
    "basket-api",
    "catalog-api",
    "identity-api",
    "ordering-api",
    "order-processor",
    "payment-processor",
    "webhooks-api",
    "webapp",
    "webhook-client"
  ]

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# EKS Module
# ============================================================================

module "eks" {
  source = "../../modules/eks"

  environment = local.environment
  name_prefix = local.name_prefix

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_version     = var.eks_cluster_version
  node_instance_types = local.eks_node_instance_types
  min_size            = local.eks_min_size
  max_size            = local.eks_max_size
  desired_size        = local.eks_desired_size

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# RDS Module
# ============================================================================

module "rds" {
  source = "../../modules/rds"

  environment = local.environment
  name_prefix = local.name_prefix

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  engine_version          = var.rds_engine_version
  instance_class          = local.rds_instance_class
  allocated_storage       = local.rds_allocated_storage
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = var.rds_skip_final_snapshot

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# ElastiCache Module
# ============================================================================

module "elasticache" {
  source = "../../modules/elasticache"

  environment = local.environment
  name_prefix = local.name_prefix

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_type       = local.elasticache_node_type
  num_cache_nodes = var.elasticache_num_cache_nodes
  engine_version  = var.elasticache_engine_version

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# AWS Secrets Manager Module
# ============================================================================

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment = local.environment
  name_prefix = local.name_prefix

  rds_username = var.rds_master_username
  rds_password = var.rds_master_password

  redis_password = var.redis_password

  jwt_secret = var.jwt_signing_secret

  rabbitmq_username = var.rabbitmq_username
  rabbitmq_password = var.rabbitmq_password

  api_keys = var.api_keys

  additional_secrets = var.additional_secrets

  kms_key_id = var.secrets_kms_key_id

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# Kubernetes Secrets Store CSI Driver Module
# ============================================================================

module "k8s_csi_driver" {
  source = "../../modules/k8s-csi-driver"

  enabled             = false  # Disabled - wegen K8s Provider Issue
  cluster_name        = module.eks.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url

  namespace           = "kube-system"
  ascp_namespace      = "kube-system"
  create_service_account = true

  tags = merge(var.common_tags, {
    Environment = "development"
  })
}

# ============================================================================
# RabbitMQ Helm Module
# ============================================================================

module "rabbitmq" {
  source = "../../modules/rabbitmq"

  namespace = "rabbitmq"
  enabled   = var.rabbitmq_enabled

  chart_version = var.rabbitmq_chart_version
  replica_count = var.rabbitmq_replica_count
  storage_size  = var.rabbitmq_storage_size

  rabbitmq_username = var.rabbitmq_username
  rabbitmq_password = var.rabbitmq_password

  resources = var.rabbitmq_resources

  image_repository = "bitnami/rabbitmq"
  image_tag        = "3.12"

  management_ui_enabled = true
  management_ui_port    = 15672

  metrics_enabled     = false
  service_type        = "ClusterIP"
  persistence_enabled = true

  extra_plugins = [
    "rabbitmq_management",
    "rabbitmq_management_agent",
    "rabbitmq_prometheus",
  ]

  tags = merge(var.common_tags, {
    Environment = "development"
  })

  depends_on = [module.eks]
}

# ============================================================================
# Monitoring Stack Module (Prometheus, Grafana, Alertmanager)
# ============================================================================

module "monitoring" {
  count   = var.monitoring_enabled ? 1 : 0
  source  = "../../modules/monitoring/prometheus"

  namespace                   = "monitoring"
  enabled                     = true
  chart_version               = var.prometheus_chart_version
  prometheus_replica_count    = var.prometheus_replica_count
  retention_days              = var.prometheus_retention_days
  storage_size                = var.prometheus_storage_size
  scrape_interval             = var.prometheus_scrape_interval
  evaluation_interval         = var.prometheus_evaluation_interval
  prometheus_resources        = var.prometheus_resources
  node_exporter_enabled       = var.node_exporter_enabled
  kube_state_metrics_enabled  = var.kube_state_metrics_enabled
  alertmanager_enabled        = var.alertmanager_enabled
  grafana_enabled             = var.grafana_enabled
  grafana_admin_password      = var.grafana_admin_password

  # Email Notification Configuration
  alertmanager_smtp_host     = var.alertmanager_smtp_host
  alertmanager_smtp_port     = var.alertmanager_smtp_port
  alertmanager_smtp_user     = var.alertmanager_smtp_user
  alertmanager_smtp_password = var.alertmanager_smtp_password
  alertmanager_email_from    = var.alertmanager_email_from
  alertmanager_email_to      = var.alertmanager_email_to

  external_labels = {
    cluster     = "eshop-dev"
    environment = "development"
  }

  tags = merge(var.common_tags, {
    Environment = "development"
  })

  depends_on = [module.eks, module.rabbitmq]
}

# ============================================================================
# CloudWatch Logging Module (Log Groups + IAM)
# ============================================================================

module "cloudwatch_logging" {
  count   = var.logging_enabled ? 1 : 0
  source  = "../../modules/logging/cloudwatch"

  cluster_name           = module.eks.cluster_name
  environment            = local.environment
  region                 = var.aws_region
  log_retention_days     = var.cloudwatch_log_retention_days
  enable_kms_encryption  = var.cloudwatch_enable_kms_encryption
  kms_key_arn            = var.cloudwatch_kms_key_arn
  oidc_provider_arn      = module.eks.oidc_provider_arn
  create_fluent_bit_role = var.fluent_bit_enabled

  tags = merge(var.common_tags, {
    Environment = "development"
  })

  depends_on = [module.eks]
}

# ============================================================================
# Fluent Bit Helm Module (Log Forwarding DaemonSet)
# ============================================================================

module "fluent_bit" {
  count   = var.fluent_bit_enabled ? 1 : 0
  source  = "../../modules/logging/fluent-bit"

  cluster_name                       = module.eks.cluster_name
  environment                        = local.environment
  region                             = var.aws_region
  kubernetes_namespace               = "logging"
  service_account_name               = "fluent-bit"
  fluent_bit_enabled                 = true
  fluent_bit_chart_version           = var.fluent_bit_chart_version
  fluent_bit_image_tag               = var.fluent_bit_image_tag
  cloudwatch_log_group_prefix        = "/aws/eks"
  fluent_bit_role_arn                = var.logging_enabled ? module.cloudwatch_logging[0].fluent_bit_role_arn : ""
  fluent_bit_resources               = var.fluent_bit_resources
  buffer_size                        = var.fluent_bit_buffer_size
  enable_container_insights          = var.fluent_bit_enable_container_insights
  log_format_multiline               = var.fluent_bit_enable_multiline_parsing

  tags = merge(var.common_tags, {
    Environment = "development"
  })

  depends_on = [
    module.eks,
    module.cloudwatch_logging,
  ]
}

# ============================================================================
# Outputs
# ============================================================================


output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "ElastiCache endpoint"
  value       = module.elasticache.endpoint
  sensitive   = true
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "rabbitmq_connection_string" {
  description = "RabbitMQ AMQP connection string"
  value       = module.rabbitmq.amqp_connection_string
  sensitive   = true
}

output "rabbitmq_management_ui_url" {
  description = "RabbitMQ Management UI URL"
  value       = module.rabbitmq.management_ui_url
}

output "rabbitmq_service_fqdn" {
  description = "RabbitMQ service FQDN"
  value       = module.rabbitmq.service_fqdn
}

output "secrets_manager_arns" {
  description = "AWS Secrets Manager secret ARNs"
  value = {
    rds      = module.secrets_manager.rds_secret_arn
    jwt      = module.secrets_manager.jwt_secret_arn
    rabbitmq = module.secrets_manager.rabbitmq_secret_arn
    redis    = module.secrets_manager.redis_secret_arn
    api_keys = module.secrets_manager.api_keys_secret_arn
  }
}

output "k8s_csi_driver_status" {
  description = "Kubernetes Secrets Store CSI Driver deployment status"
  value = {
    secrets_store_csi_driver = module.k8s_csi_driver.secrets_store_csi_driver_status
    ascp                     = module.k8s_csi_driver.ascp_status
    csi_driver_role_arn      = module.k8s_csi_driver.csi_driver_role_arn
  }
}

# ============================================================================
# Monitoring Stack Outputs
# ============================================================================

output "monitoring_enabled" {
  description = "Whether monitoring stack is enabled"
  value       = var.monitoring_enabled
}

output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value       = var.monitoring_enabled ? module.monitoring[0].prometheus_endpoint : null
}

output "prometheus_url" {
  description = "Full URL to access Prometheus"
  value       = var.monitoring_enabled ? module.monitoring[0].prometheus_url : null
}

output "grafana_endpoint" {
  description = "Grafana server endpoint"
  value       = var.monitoring_enabled ? module.monitoring[0].grafana_endpoint : null
}

output "grafana_url" {
  description = "Full URL to access Grafana"
  value       = var.monitoring_enabled ? module.monitoring[0].grafana_url : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.monitoring_enabled ? module.monitoring[0].grafana_admin_password : null
  sensitive   = true
}

output "alertmanager_endpoint" {
  description = "Alertmanager server endpoint"
  value       = var.monitoring_enabled ? module.monitoring[0].alertmanager_endpoint : null
}

output "alertmanager_url" {
  description = "Full URL to access Alertmanager"
  value       = var.monitoring_enabled ? module.monitoring[0].alertmanager_url : null
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = var.monitoring_enabled ? module.monitoring[0].namespace : null
}

output "monitoring_deployment_info" {
  description = "Summary of monitoring stack deployment"
  value       = var.monitoring_enabled ? module.monitoring[0].deployment_info : null
}

# ============================================================================
# CloudWatch Logging Outputs
# ============================================================================

output "logging_enabled" {
  description = "Whether centralized logging is enabled"
  value       = var.logging_enabled
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log group names for services"
  value       = var.logging_enabled ? module.cloudwatch_logging[0].log_group_names : {}
}

output "cloudwatch_log_group_arns" {
  description = "CloudWatch Log group ARNs for services"
  value       = var.logging_enabled ? module.cloudwatch_logging[0].log_group_arns : {}
}

output "cloudwatch_platform_log_group_name" {
  description = "CloudWatch platform/system log group name"
  value       = var.logging_enabled ? module.cloudwatch_logging[0].platform_log_group_name : null
}

output "cloudwatch_platform_log_group_arn" {
  description = "CloudWatch platform/system log group ARN"
  value       = var.logging_enabled ? module.cloudwatch_logging[0].platform_log_group_arn : null
}

output "fluent_bit_enabled" {
  description = "Whether Fluent Bit log forwarding is enabled"
  value       = var.fluent_bit_enabled
}

output "fluent_bit_namespace" {
  description = "Kubernetes namespace for Fluent Bit"
  value       = var.fluent_bit_enabled ? module.fluent_bit[0].fluent_bit_namespace : null
}

output "fluent_bit_service_account" {
  description = "Kubernetes service account for Fluent Bit IRSA"
  value       = var.fluent_bit_enabled ? module.fluent_bit[0].fluent_bit_service_account : null
}

output "fluent_bit_helm_release_status" {
  description = "Status of Fluent Bit Helm release"
  value       = var.fluent_bit_enabled ? module.fluent_bit[0].fluent_bit_helm_release_status : null
}

output "fluent_bit_deployment_info" {
  description = "Summary of Fluent Bit deployment configuration"
  value       = var.fluent_bit_enabled ? module.fluent_bit[0].deployment_info : null
}

output "logging_deployment_summary" {
  description = "Complete summary of logging infrastructure deployment"
  value = {
    logging_enabled           = var.logging_enabled
    cloudwatch_enabled        = var.logging_enabled
    fluent_bit_enabled        = var.fluent_bit_enabled
    log_retention_days        = var.cloudwatch_log_retention_days
    kms_encryption_enabled    = var.cloudwatch_enable_kms_encryption
    fluent_bit_namespace      = var.fluent_bit_enabled ? module.fluent_bit[0].fluent_bit_namespace : null
    fluent_bit_service_account = var.fluent_bit_enabled ? module.fluent_bit[0].fluent_bit_service_account : null
    cloudwatch_log_group_count = var.logging_enabled ? length(module.cloudwatch_logging[0].log_group_names) : 0
    platform_log_group        = var.logging_enabled ? module.cloudwatch_logging[0].platform_log_group_name : null
  }
}