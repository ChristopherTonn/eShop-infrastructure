# ============================================================================
# ECR Module - Main Configuration
# ============================================================================

# ECR Repositories
resource "aws_ecr_repository" "main" {
  for_each = toset(var.repositories)

  name                 = "${var.name_prefix}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.enable_image_scanning
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-${each.value}"
    Type       = "ecr-repository"
    Service    = each.value
  })
}

# Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = var.enable_lifecycle_policy ? toset(var.repositories) : toset([])

  repository = aws_ecr_repository.main[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "staging", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository Policies for CI/CD access
resource "aws_ecr_repository_policy" "main" {
  for_each = toset(var.repositories)

  repository = aws_ecr_repository.main[each.value].name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchDeleteImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}