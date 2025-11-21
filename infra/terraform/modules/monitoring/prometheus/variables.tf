# ============================================================================
# Prometheus Stack Helm Module - Input Variables
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Prometheus deployment"
  type        = string
  default     = "monitoring"
}

variable "enabled" {
  description = "Whether to deploy Prometheus Helm chart"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "25.3.1"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.chart_version))
    error_message = "Chart version must follow semantic versioning."
  }
}

variable "prometheus_replica_count" {
  description = "Number of Prometheus server replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.prometheus_replica_count >= 1 && var.prometheus_replica_count <= 5
    error_message = "Replica count must be between 1 and 5."
  }
}

variable "retention_days" {
  description = "Prometheus data retention period in days"
  type        = number
  default     = 15

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 365
    error_message = "Retention days must be between 1 and 365."
  }
}

variable "storage_size" {
  description = "Prometheus persistent volume size"
  type        = string
  default     = "10Gi"

  validation {
    condition     = can(regex("^\\d+Gi$", var.storage_size))
    error_message = "Storage size must be in Gi format (e.g., 10Gi)."
  }
}

variable "storage_class" {
  description = "Kubernetes storage class for Prometheus PVC"
  type        = string
  default     = "gp2"
}

variable "prometheus_resources" {
  description = "Prometheus pod resource requests and limits"
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
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "node_exporter_enabled" {
  description = "Deploy Node Exporter for hardware metrics"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "Deploy kube-state-metrics for Kubernetes metrics"
  type        = bool
  default     = true
}

variable "prometheus_operator_enabled" {
  description = "Deploy Prometheus Operator"
  type        = bool
  default     = true
}

variable "alertmanager_enabled" {
  description = "Deploy Alertmanager component"
  type        = bool
  default     = true
}

variable "grafana_enabled" {
  description = "Deploy Grafana component"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password (will be randomly generated if not provided)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "service_type" {
  description = "Kubernetes service type for Prometheus"
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "scrape_interval" {
  description = "Prometheus scrape interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.scrape_interval >= 5 && var.scrape_interval <= 300
    error_message = "Scrape interval must be between 5 and 300 seconds."
  }
}

variable "evaluation_interval" {
  description = "Prometheus evaluation interval for alert rules in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.evaluation_interval >= 5 && var.evaluation_interval <= 300
    error_message = "Evaluation interval must be between 5 and 300 seconds."
  }
}

variable "external_labels" {
  description = "External labels to add to all metrics"
  type        = map(string)
  default = {
    cluster = "eshop-dev"
  }
}

variable "helm_repository_url" {
  description = "Prometheus community Helm repository URL"
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
