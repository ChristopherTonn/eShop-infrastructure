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

  backend "s3" {
    bucket         = "eshop-1763393223-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-1763393223-terraform-lock-dev"
    encrypt        = true
  }
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
  eks_desired_size       = 2
  eks_min_size          = 1
  eks_max_size          = 5
  
  rds_instance_class     = "db.t3.micro"
  rds_allocated_storage  = 20
  
  elasticache_node_type = "cache.t3.micro"
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
  
  engine_version           = var.rds_engine_version
  instance_class           = local.rds_instance_class
  allocated_storage        = local.rds_allocated_storage
  backup_retention_period  = var.rds_backup_retention_period
  
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
  
  node_type          = local.elasticache_node_type
  num_cache_nodes    = var.elasticache_num_cache_nodes
  engine_version     = var.elasticache_engine_version
  
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