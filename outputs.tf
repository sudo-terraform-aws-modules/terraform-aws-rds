output "id" {
  description = "ID of the DB instance."
  value       = aws_db_instance.this.id
}

output "arn" {
  description = "ARN of the DB instance."
  value       = aws_db_instance.this.arn
}

output "identifier" {
  description = "Identifier of the DB instance."
  value       = aws_db_instance.this.identifier
}

output "resource_id" {
  description = "RDS resource ID of the DB instance (used for IAM database authentication ARNs)."
  value       = aws_db_instance.this.resource_id
}

output "status" {
  description = "Current status of the DB instance."
  value       = aws_db_instance.this.status
}

output "endpoint" {
  description = "Connection endpoint of the DB instance, in address:port format."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the DB instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the DB instance listens on."
  value       = aws_db_instance.this.port
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID of the DB instance."
  value       = aws_db_instance.this.hosted_zone_id
}

output "username" {
  description = "Master username of the DB instance."
  value       = aws_db_instance.this.username
}

output "master_user_secret" {
  description = "Details of the AWS-managed master user secret (secret_arn, kms_key_id, secret_status), or null when manage_master_user_password is false."
  value       = try(aws_db_instance.this.master_user_secret[0], null)
  sensitive   = true
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group, or null when create_db_subnet_group is false."
  value       = try(aws_db_subnet_group.this[0].id, null)
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group in use, whether module-managed or caller-supplied."
  value       = local.db_subnet_group_name
}

output "security_group_id" {
  description = "ID of the security group created by this module, or null when create_security_group is false."
  value       = try(aws_security_group.this[0].id, null)
}

output "parameter_group_name" {
  description = "Name of the DB parameter group in use, whether module-managed or caller-supplied, or null when neither is set."
  value       = local.parameter_group_name
}

output "option_group_name" {
  description = "Name of the DB option group in use, whether module-managed or caller-supplied, or null when neither is set."
  value       = local.option_group_name
}

output "enhanced_monitoring_iam_role_arn" {
  description = "ARN of the IAM role used for Enhanced Monitoring, or null when not applicable."
  value       = local.monitoring_role_arn
}

output "read_replica_ids" {
  description = "Map of read replica keys to their DB instance IDs."
  value       = { for k, v in aws_db_instance.read_replica : k => v.id }
}

output "read_replica_arns" {
  description = "Map of read replica keys to their DB instance ARNs."
  value       = { for k, v in aws_db_instance.read_replica : k => v.arn }
}

output "read_replica_endpoints" {
  description = "Map of read replica keys to their connection endpoints."
  value       = { for k, v in aws_db_instance.read_replica : k => v.endpoint }
}
