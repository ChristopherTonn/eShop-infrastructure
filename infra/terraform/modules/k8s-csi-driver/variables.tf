# ============================================================================
# AWS Secrets and Configuration Provider (ASCP) for Kubernetes
# Helm Installation and Configuration
# ============================================================================
# This module installs and configures the AWS Secrets and Configuration
# Provider (ASCP) which allows pods to access AWS Secrets Manager secrets
# and AWS Systems Manager Parameter Store parameters as Kubernetes secrets.

variable "enabled" {
  description = "Enable CSI driver installation"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for CSI driver"
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "Helm chart version for secrets-store-csi-driver"
  type        = string
  default     = "1.3.4"
}

variable "create_service_account" {
  description = "Create IAM service account for ASCP"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "ascp_namespace" {
  description = "Kubernetes namespace where ASCP runs"
  type        = string
  default     = "kube-system"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Kubernetes Secret Store CSI Driver Installation
# ============================================================================

resource "helm_release" "secrets_store_csi_driver" {
  count            = var.enabled ? 1 : 0
  name             = "secrets-store-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart            = "secrets-store-csi-driver"
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "rotationPollInterval"
    value = "120s"
  }
}

# ============================================================================
# AWS Secrets and Configuration Provider Installation
# ============================================================================

resource "helm_release" "aws_secrets_store" {
  count      = var.enabled ? 1 : 0
  depends_on = [helm_release.secrets_store_csi_driver]

  name       = "aws-secrets-store"
  repository = "https://aws.github.io/aws-secrets-manager-csi-driver-provider-for-kubernetes"
  chart      = "secrets-store-aws-provider"
  namespace  = var.ascp_namespace
  version    = "0.3.4"

  set {
    name  = "serviceAccount.create"
    value = var.create_service_account ? "true" : "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "csi-secrets-store-provider-aws"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.create_service_account ? aws_iam_role.csi_driver[0].arn : ""
  }
}

# ============================================================================
# IAM Service Account for ASCP (IRSA - IAM Roles for Service Accounts)
# ============================================================================

data "http" "oidc_provider_thumbprint" {
  count = var.enabled ? 1 : 0
  url   = var.oidc_provider_url
}

resource "aws_iam_role" "csi_driver" {
  count = var.enabled && var.create_service_account ? 1 : 0

  name = "${var.cluster_name}-csi-secrets-store-provider"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.ascp_namespace}:csi-secrets-store-provider-aws"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-csi-secrets-store-provider"
  })
}

# ============================================================================
# IAM Policy for ASCP - AWS Secrets Manager Permissions
# ============================================================================

resource "aws_iam_role_policy" "csi_driver_secrets" {
  count = var.enabled && var.create_service_account ? 1 : 0

  name   = "${var.cluster_name}-csi-secrets-manager-policy"
  role   = aws_iam_role.csi_driver[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:eshop-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM Policy for ASCP - Systems Manager Parameters Permissions
# ============================================================================

resource "aws_iam_role_policy" "csi_driver_ssm" {
  count = var.enabled && var.create_service_account ? 1 : 0

  name   = "${var.cluster_name}-csi-ssm-parameters-policy"
  role   = aws_iam_role.csi_driver[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/eshop/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.eu-central-1.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "secrets_store_csi_driver_status" {
  description = "Status of secrets-store-csi-driver installation"
  value       = var.enabled ? "installed" : "disabled"
}

output "ascp_status" {
  description = "Status of AWS Secrets and Configuration Provider installation"
  value       = var.enabled ? "installed" : "disabled"
}

output "csi_driver_role_arn" {
  description = "ARN of the CSI driver IAM role"
  value       = try(aws_iam_role.csi_driver[0].arn, null)
}

output "csi_driver_role_name" {
  description = "Name of the CSI driver IAM role"
  value       = try(aws_iam_role.csi_driver[0].name, null)
}
