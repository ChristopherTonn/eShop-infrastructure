# ============================================================================
# Terraform State Backend Bootstrap
# This creates S3 bucket and DynamoDB table for Terraform state management
# Run this FIRST before any other Terraform configurations
# ============================================================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: This bootstrap runs without a backend initially
  # After S3 bucket is created, migrate state to the bucket
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "eShop"
      Environment = "infrastructure"
      ManagedBy   = "Terraform"
      Purpose     = "StateManagement"
    }
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eshop"
}

# ============================================================================
# S3 Buckets for Terraform State
# ============================================================================

resource "aws_s3_bucket" "terraform_state_dev" {
  bucket = "${var.project_name}-terraform-state-dev"

  tags = {
    Name        = "${var.project_name}-terraform-state-dev"
    Environment = "development"
    Type        = "terraform-state"
  }
}

resource "aws_s3_bucket" "terraform_state_staging" {
  bucket = "${var.project_name}-terraform-state-staging"

  tags = {
    Name        = "${var.project_name}-terraform-state-staging"
    Environment = "staging"
    Type        = "terraform-state"
  }
}

resource "aws_s3_bucket" "terraform_state_prod" {
  bucket = "${var.project_name}-terraform-state-prod"

  tags = {
    Name        = "${var.project_name}-terraform-state-prod"
    Environment = "production"
    Type        = "terraform-state"
  }
}

# ============================================================================
# S3 Bucket Configurations
# ============================================================================

# Versioning
resource "aws_s3_bucket_versioning" "terraform_state_dev" {
  bucket = aws_s3_bucket.terraform_state_dev.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_staging" {
  bucket = aws_s3_bucket.terraform_state_staging.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_dev" {
  bucket = aws_s3_bucket.terraform_state_dev.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_staging" {
  bucket = aws_s3_bucket.terraform_state_staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state_dev" {
  bucket = aws_s3_bucket.terraform_state_dev.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "terraform_state_staging" {
  bucket = aws_s3_bucket.terraform_state_staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "terraform_state_prod" {
  bucket = aws_s3_bucket.terraform_state_prod.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# DynamoDB Tables for State Locking
# ============================================================================

resource "aws_dynamodb_table" "terraform_lock_dev" {
  name           = "${var.project_name}-terraform-lock-dev"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-lock-dev"
    Environment = "development"
    Type        = "terraform-lock"
  }
}

resource "aws_dynamodb_table" "terraform_lock_staging" {
  name           = "${var.project_name}-terraform-lock-staging"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-lock-staging"
    Environment = "staging"
    Type        = "terraform-lock"
  }
}

resource "aws_dynamodb_table" "terraform_lock_prod" {
  name           = "${var.project_name}-terraform-lock-prod"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-lock-prod"
    Environment = "production"
    Type        = "terraform-lock"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "s3_bucket_names" {
  description = "S3 bucket names for Terraform state"
  value = {
    dev     = aws_s3_bucket.terraform_state_dev.bucket
    staging = aws_s3_bucket.terraform_state_staging.bucket
    prod    = aws_s3_bucket.terraform_state_prod.bucket
  }
}

output "dynamodb_table_names" {
  description = "DynamoDB table names for Terraform locking"
  value = {
    dev     = aws_dynamodb_table.terraform_lock_dev.name
    staging = aws_dynamodb_table.terraform_lock_staging.name
    prod    = aws_dynamodb_table.terraform_lock_prod.name
  }
}

output "backend_configurations" {
  description = "Backend configurations for each environment"
  value = {
    dev = {
      bucket         = aws_s3_bucket.terraform_state_dev.bucket
      key            = "dev/terraform.tfstate"
      region         = var.aws_region
      dynamodb_table = aws_dynamodb_table.terraform_lock_dev.name
      encrypt        = true
    }
    staging = {
      bucket         = aws_s3_bucket.terraform_state_staging.bucket
      key            = "staging/terraform.tfstate"
      region         = var.aws_region
      dynamodb_table = aws_dynamodb_table.terraform_lock_staging.name
      encrypt        = true
    }
    prod = {
      bucket         = aws_s3_bucket.terraform_state_prod.bucket
      key            = "prod/terraform.tfstate"
      region         = var.aws_region
      dynamodb_table = aws_dynamodb_table.terraform_lock_prod.name
      encrypt        = true
    }
  }
}