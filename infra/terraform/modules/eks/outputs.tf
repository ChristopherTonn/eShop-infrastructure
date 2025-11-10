# ============================================================================
# EKS Module - Outputs
# ============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = local.cluster_endpoint
  sensitive   = true
}

# TODO: Add more outputs when implementing actual EKS resources:
# - cluster_arn
# - cluster_certificate_authority_data
# - cluster_security_group_id
# - node_security_group_id
# - oidc_provider_arn