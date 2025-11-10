# ============================================================================
# EKS Module - Variables
# ============================================================================

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "Instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 10
}

variable "desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 3
}

variable "enable_cluster_encryption" {
  description = "Enable cluster encryption"
  type        = bool
  default     = false
}

variable "enable_pod_security_policy" {
  description = "Enable pod security policy"
  type        = bool
  default     = false
}

variable "enable_network_policy" {
  description = "Enable network policy"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "EC2 SSH Key name for node group access"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}