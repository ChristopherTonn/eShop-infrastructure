# ============================================================================
# K8s CSI Driver Module - Outputs
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
