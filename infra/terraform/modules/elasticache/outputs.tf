# ============================================================================
# ElastiCache Module - Outputs
# ============================================================================

output "endpoint" {
  description = "ElastiCache endpoint"
  value       = local.endpoint
  sensitive   = true
}

# TODO: Add more outputs when implementing actual ElastiCache resources:
# - replication_group_id
# - primary_endpoint
# - configuration_endpoint
# - security_group_id