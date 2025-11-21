# ============================================================================
# RabbitMQ Helm Module - Input Variables
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for RabbitMQ deployment"
  type        = string
}

variable "enabled" {
  description = "Whether to deploy RabbitMQ Helm chart"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "RabbitMQ Helm chart version"
  type        = string
  default     = "13.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.chart_version))
    error_message = "Chart version must follow semantic versioning (e.g., 13.0.0)."
  }
}

variable "replica_count" {
  description = "Number of RabbitMQ replicas to deploy"
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "storage_size" {
  description = "PVC storage size for RabbitMQ persistent volume"
  type        = string
  default     = "5Gi"

  validation {
    condition     = can(regex("^\\d+Gi$", var.storage_size))
    error_message = "Storage size must be specified in Gi format (e.g., 5Gi)."
  }
}

variable "storage_class" {
  description = "Kubernetes storage class for persistent volume claim"
  type        = string
  default     = "gp2"
}

variable "rabbitmq_username" {
  description = "RabbitMQ default user username"
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ default user password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.rabbitmq_password) >= 8
    error_message = "RabbitMQ password must be at least 8 characters long."
  }
}

variable "resources" {
  description = "RabbitMQ pod resource requests and limits"
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
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "image_repository" {
  description = "RabbitMQ container image repository"
  type        = string
  default     = "bitnami/rabbitmq"
}

variable "image_tag" {
  description = "RabbitMQ container image tag"
  type        = string
  default     = "3.12"
}

variable "erlang_cookie" {
  description = "Erlang cookie for RabbitMQ clustering"
  type        = string
  sensitive   = true
  default     = ""
}

variable "metrics_enabled" {
  description = "Enable RabbitMQ metrics collection"
  type        = bool
  default     = false
}

variable "management_ui_enabled" {
  description = "Enable RabbitMQ management UI (web console)"
  type        = bool
  default     = true
}

variable "management_ui_port" {
  description = "Port for RabbitMQ management UI"
  type        = number
  default     = 15672

  validation {
    condition     = var.management_ui_port >= 1024 && var.management_ui_port <= 65535
    error_message = "Management UI port must be between 1024 and 65535."
  }
}

variable "amqp_port" {
  description = "Port for RabbitMQ AMQP protocol"
  type        = number
  default     = 5672

  validation {
    condition     = var.amqp_port >= 1024 && var.amqp_port <= 65535
    error_message = "AMQP port must be between 1024 and 65535."
  }
}

variable "node_selector" {
  description = "Node selector for RabbitMQ pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for RabbitMQ pods"
  type        = list(any)
  default     = []
}

variable "affinity" {
  description = "Affinity rules for RabbitMQ pods"
  type        = any
  default     = {}
}

variable "service_type" {
  description = "Kubernetes service type for RabbitMQ"
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "persistence_enabled" {
  description = "Enable persistence for RabbitMQ"
  type        = bool
  default     = true
}

variable "helm_repository_url" {
  description = "Bitnami Helm repository URL"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}

variable "environment_variables" {
  description = "Additional environment variables for RabbitMQ pods"
  type        = map(string)
  default     = {}
}

variable "extra_plugins" {
  description = "Additional RabbitMQ plugins to enable"
  type        = list(string)
  default     = ["rabbitmq_management", "rabbitmq_management_agent"]
}

variable "queue_master_location" {
  description = "Queue master location policy (all, nodes, or min-masters)"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["all", "nodes", "min-masters"], var.queue_master_location)
    error_message = "Queue master location must be 'all', 'nodes', or 'min-masters'."
  }
}

variable "memory_high_watermark" {
  description = "Memory high watermark threshold (0.0-1.0)"
  type        = number
  default     = 0.6

  validation {
    condition     = var.memory_high_watermark > 0 && var.memory_high_watermark <= 1
    error_message = "Memory high watermark must be between 0 and 1."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
