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

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for Fluent Bit deployment"
  type        = string
  default     = "logging"
}

variable "fluent_bit_enabled" {
  description = "Enable Fluent Bit deployment"
  type        = bool
  default     = true
}

variable "fluent_bit_chart_version" {
  description = "Fluent Bit Helm chart version"
  type        = string
  default     = "0.21.0"
}

variable "fluent_bit_replica_count" {
  description = "Number of Fluent Bit replicas (ignored for DaemonSet)"
  type        = number
  default     = 1
  validation {
    condition     = var.fluent_bit_replica_count >= 1 && var.fluent_bit_replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "fluent_bit_repository" {
  description = "Fluent Bit Helm chart repository"
  type        = string
  default     = "https://fluent.github.io/helm-charts"
}

variable "fluent_bit_image_repository" {
  description = "Fluent Bit image repository"
  type        = string
  default     = "fluent/fluent-bit"
}

variable "fluent_bit_image_tag" {
  description = "Fluent Bit image tag"
  type        = string
  default     = "2.1.8"
}

variable "log_group_names" {
  description = "Map of service names to CloudWatch Log group names"
  type        = map(string)
  default     = {}
}

variable "cloudwatch_log_group_prefix" {
  description = "CloudWatch Log group name prefix (base path)"
  type        = string
  default     = "/aws/eks"
}

variable "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit IRSA"
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "Kubernetes service account name for Fluent Bit"
  type        = string
  default     = "fluent-bit"
}

variable "fluent_bit_resources" {
  description = "CPU and memory resources for Fluent Bit"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights log formatting"
  type        = bool
  default     = true
}

variable "log_format_multiline" {
  description = "Enable multiline log parsing"
  type        = bool
  default     = true
}

variable "buffer_size" {
  description = "Fluent Bit buffer size limit (e.g., '32m')"
  type        = string
  default     = "32m"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "depends_on_modules" {
  description = "Explicit dependency on other modules (for ordering)"
  type        = list(any)
  default     = []
}
