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

  enabled             = true
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