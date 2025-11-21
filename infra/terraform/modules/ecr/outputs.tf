# ============================================================================
# ECR Module - Outputs
# ============================================================================

output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    for repo, details in aws_ecr_repository.main : repo => details.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to ARNs"
  value = {
    for repo, details in aws_ecr_repository.main : repo => details.arn
  }
}

output "registry_id" {
  description = "Registry ID where repositories are created"
  value       = data.aws_caller_identity.current.account_id
}