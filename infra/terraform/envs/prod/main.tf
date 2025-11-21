# ============================================================================
# eShop Infrastructure - Production Environment
# ============================================================================

terraform {
  required_version = ">= 1.6"

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

  # TODO: Configure after S3 bucket is created
  # backend "s3" {
  #   bucket         = "eshop-terraform-state-prod"
  #   key            = "prod/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "eshop-terraform-lock-prod"
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
      Environment = "production"
      CostCenter  = "production"
      Criticality = "high"
    })
  }
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  environment = "prod"
  name_prefix = "${var.project_name}-${local.environment}"

  # Production-specific configuration
  vpc_cidr = "10.2.0.0/16"

  # Production-grade instances
  eks_node_instance_types = ["m5.large", "m5.xlarge"]
  eks_desired_size        = 6
  eks_min_size            = 3
  eks_max_size            = 15

  rds_instance_class    = "db.r6g.large"
  rds_allocated_storage = 200

  elasticache_node_type = "cache.r6g.large"
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

  enable_vpc_flow_logs = true # Always enabled for production

  tags = merge(var.common_tags, {
    Environment = "production"
    Criticality = "high"
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

  # Enhanced security for production
  enable_image_scanning   = true
  enable_lifecycle_policy = true

  tags = merge(var.common_tags, {
    Environment = "production"
    Criticality = "high"
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

  # Production security enhancements
  enable_cluster_encryption  = true
  enable_pod_security_policy = true
  enable_network_policy      = true

  tags = merge(var.common_tags, {
    Environment = "production"
    Criticality = "high"
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
  backup_retention_period = 30 # 30 days for production

  # Production features
  multi_az                    = true
  enable_performance_insights = true
  enable_encryption           = true
  enable_deletion_protection  = true

  tags = merge(var.common_tags, {
    Environment = "production"
    Criticality = "high"
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
  num_cache_nodes = 3 # High availability for production
  engine_version  = var.elasticache_engine_version

  # Production features
  enable_encryption_at_rest    = true
  enable_encryption_in_transit = true
  enable_backup                = true

  tags = merge(var.common_tags, {
    Environment = "production"
    Criticality = "high"
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