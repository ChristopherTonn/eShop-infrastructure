# ============================================================================
# eShop Infrastructure - Staging Environment
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
  #   bucket         = "eshop-terraform-state-staging"
  #   key            = "staging/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "eshop-terraform-lock-staging"
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
      Environment = "staging"
      CostCenter  = "pre-production"
    })
  }
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  environment = "staging"
  name_prefix = "${var.project_name}-${local.environment}"
  
  # Staging-specific configuration
  vpc_cidr = "10.1.0.0/16"
  
  # Medium-sized instances for staging
  eks_node_instance_types = ["t3.medium", "t3.large"]
  eks_desired_size       = 3
  eks_min_size          = 2
  eks_max_size          = 8
  
  rds_instance_class     = "db.t3.small"
  rds_allocated_storage  = 50
  
  elasticache_node_type = "cache.t3.small"
}

# ============================================================================
# VPC Module
# ============================================================================

module "vpc" {
  source = "../../modules/vpc"
  
  environment        = local.environment
  name_prefix       = local.name_prefix
  vpc_cidr          = local.vpc_cidr
  availability_zones = var.availability_zones
  
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  
  tags = merge(var.common_tags, {
    Environment = "staging"
  })
}

# ============================================================================
# ECR Module (Shared with Dev)
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
    Environment = "staging"
  })
}

# ============================================================================
# EKS Module
# ============================================================================

module "eks" {
  source = "../../modules/eks"
  
  environment   = local.environment
  name_prefix   = local.name_prefix
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  cluster_version    = var.eks_cluster_version
  node_instance_types = local.eks_node_instance_types
  min_size          = local.eks_min_size
  max_size          = local.eks_max_size
  desired_size      = local.eks_desired_size
  
  tags = merge(var.common_tags, {
    Environment = "staging"
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
  
  engine_version           = var.rds_engine_version
  instance_class           = local.rds_instance_class
  allocated_storage        = local.rds_allocated_storage
  backup_retention_period  = 14 # Longer retention for staging
  
  tags = merge(var.common_tags, {
    Environment = "staging"
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
  
  node_type          = local.elasticache_node_type
  num_cache_nodes    = 2 # More nodes for staging
  engine_version     = var.elasticache_engine_version
  
  tags = merge(var.common_tags, {
    Environment = "staging"
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