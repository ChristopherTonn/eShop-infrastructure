# ============================================================================
# ECR Module - Variables
# ============================================================================

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names"
  type        = list(string)
}

variable "enable_image_scanning" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}