# ============================================================================
# RDS Module - Outputs
# ============================================================================

output "endpoint" {
  description = "RDS instance endpoint"
  value       = local.endpoint
  sensitive   = true
}

# TODO: Add more outputs when implementing actual RDS resources:
# - db_instance_id
# - db_instance_arn
# - db_subnet_group_id
# - security_group_id