output "endpoint" {
  description = "Connection endpoint of the primary DB instance, in address:port format."
  value       = module.rds.endpoint
}

output "security_group_id" {
  description = "ID of the module-managed security group."
  value       = module.rds.security_group_id
}

output "read_replica_endpoints" {
  description = "Map of read replica keys to their connection endpoints."
  value       = module.rds.read_replica_endpoints
}

output "cloudwatch_log_groups" {
  description = "Map of exported log types to their module-managed CloudWatch log group name and ARN."
  value       = module.rds.cloudwatch_log_groups
}

output "enhanced_monitoring_iam_role_arn" {
  description = "ARN of the IAM role used for Enhanced Monitoring."
  value       = module.rds.enhanced_monitoring_iam_role_arn
}
