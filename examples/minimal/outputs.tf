output "endpoint" {
  description = "Connection endpoint of the DB instance, in address:port format."
  value       = module.rds.endpoint
}

output "master_user_secret" {
  description = "Details of the AWS-managed master user secret."
  value       = module.rds.master_user_secret
  sensitive   = true
}
