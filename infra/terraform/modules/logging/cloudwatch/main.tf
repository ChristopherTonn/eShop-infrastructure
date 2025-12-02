locals {
  base_log_group_name = "/aws/eks/${var.cluster_name}"
  
  merged_tags = merge(
    var.tags,
    {
      Module      = "logging-cloudwatch"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Create CloudWatch Log Groups for each application service
resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = var.log_groups

  name              = "${local.base_log_group_name}/${each.key}"
  retention_in_days = each.value.retention_days != null ? each.value.retention_days : var.log_retention_days
  
  kms_key_id = var.enable_kms_encryption ? var.kms_key_arn : null

  tags = merge(
    local.merged_tags,
    each.value.tags != null ? each.value.tags : {}
  )
}

# Create unified log group for system/platform logs
resource "aws_cloudwatch_log_group" "platform_logs" {
  name              = "${local.base_log_group_name}/platform"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_kms_encryption ? var.kms_key_arn : null

  tags = merge(
    local.merged_tags,
    {
      component = "platform"
    }
  )
}

# IAM Role for Fluent Bit (IRSA)
resource "aws_iam_role" "fluent_bit" {
  count = var.create_fluent_bit_role ? 1 : 0
  name  = "eshop-fluent-bit-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account_name}"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.merged_tags
}

# IAM Policy for Fluent Bit to write to CloudWatch Logs
resource "aws_iam_role_policy" "fluent_bit_cloudwatch" {
  count  = var.create_fluent_bit_role ? 1 : 0
  name   = "eshop-fluent-bit-cloudwatch-policy-${var.environment}"
  role   = aws_iam_role.fluent_bit[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateLogStreams"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "${local.base_log_group_name}/*"
      },
      {
        Sid    = "PutLogEvents"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${local.base_log_group_name}/*"
      },
      {
        Sid    = "DescribeLogGroups"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:${local.base_log_group_name}*"
      }
    ]
  })
}

# Optional: IAM Policy for KMS encryption
resource "aws_iam_role_policy" "fluent_bit_kms" {
  count  = var.create_fluent_bit_role && var.enable_kms_encryption ? 1 : 0
  name   = "eshop-fluent-bit-kms-policy-${var.environment}"
  role   = aws_iam_role.fluent_bit[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

