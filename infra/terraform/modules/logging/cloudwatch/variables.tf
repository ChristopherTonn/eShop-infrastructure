variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch value: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653."
  }
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for CloudWatch Logs"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption (required if enable_kms_encryption=true)"
  type        = string
  default     = ""
}

variable "log_groups" {
  description = "Map of log group names to create"
  type = map(object({
    retention_days = optional(number)
    tags           = optional(map(string))
  }))
  default = {
    "basket-api" = {
      retention_days = null
      tags           = { service = "basket", component = "api" }
    }
    "catalog-api" = {
      retention_days = null
      tags           = { service = "catalog", component = "api" }
    }
    "ordering-api" = {
      retention_days = null
      tags           = { service = "ordering", component = "api" }
    }
    "identity-api" = {
      retention_days = null
      tags           = { service = "identity", component = "api" }
    }
    "webhooks-api" = {
      retention_days = null
      tags           = { service = "webhooks", component = "api" }
    }
    "order-processor" = {
      retention_days = null
      tags           = { service = "order", component = "processor" }
    }
    "payment-processor" = {
      retention_days = null
      tags           = { service = "payment", component = "processor" }
    }
    "webapp" = {
      retention_days = null
      tags           = { service = "web", component = "app" }
    }
  }
}

variable "create_fluent_bit_role" {
  description = "Create IAM role and policy for Fluent Bit service account"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN for IRSA"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for Fluent Bit service account (IRSA)"
  type        = string
  default     = "logging"
}

variable "kubernetes_service_account_name" {
  description = "Kubernetes service account name for IRSA"
  type        = string
  default     = "fluent-bit"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
