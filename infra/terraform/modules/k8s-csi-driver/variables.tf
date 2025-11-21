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
