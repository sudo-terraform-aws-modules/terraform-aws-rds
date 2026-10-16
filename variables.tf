### Identity / tags ###

variable "identifier" {
  description = "RDS instance identifier. Must start with a letter, contain only alphanumeric characters and hyphens, not end with a hyphen, and not contain two consecutive hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$", var.identifier)) && !can(regex("--", var.identifier))
    error_message = "identifier must start with a letter, be 1-63 characters of alphanumerics/hyphens, not end with a hyphen, and not contain consecutive hyphens."
  }
}

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

### Engine / instance / storage ###

variable "engine" {
  description = "Database engine to use, e.g. postgres, mysql, mariadb, oracle-se2, sqlserver-ex."
  type        = string
}

variable "engine_version" {
  description = "Engine version to use. When null, AWS selects the current default version at creation time."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Instance class for the DB instance, e.g. db.t4g.micro."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage size in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Upper limit in GiB for RDS storage autoscaling. Null disables storage autoscaling."
  type        = number
  default     = null
}

variable "storage_type" {
  description = "Storage type for the DB instance."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "storage_type must be one of: standard, gp2, gp3, io1, io2."
  }
}

variable "iops" {
  description = "Provisioned IOPS. Only applicable to io1/io2 storage, or gp3 above the baseline."
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Provisioned storage throughput in MiBps. Only applicable to gp3 storage."
  type        = number
  default     = null
}

variable "storage_encrypted" {
  description = "Whether the DB storage is encrypted at rest."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ARN of the KMS key used to encrypt storage. Null uses the AWS-managed default RDS key."
  type        = string
  default     = null
}

### Credentials ###

variable "db_name" {
  description = "Name of the initial database to create. Null skips creating an initial database."
  type        = string
  default     = null
}

variable "username" {
  description = "Master username for the DB instance."
  type        = string
}

variable "manage_master_user_password" {
  description = "Whether AWS should generate and manage the master password in Secrets Manager. When false, var.password must be supplied."
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key ARN used to encrypt the AWS-managed master user secret. Null uses the default Secrets Manager key. Ignored when manage_master_user_password is false."
  type        = string
  default     = null
}

variable "password" {
  description = "Master password. Required only when manage_master_user_password is false. Never store this in plain tfvars; source it from a secrets manager at runtime."
  type        = string
  default     = null
  sensitive   = true
}

### Networking ###

variable "create_db_subnet_group" {
  description = "Whether this module creates a DB subnet group. When false, db_subnet_group_name must reference an existing one."
  type        = bool
  default     = true
}

variable "db_subnet_group_name" {
  description = "Name of an existing DB subnet group to use when create_db_subnet_group is false."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Required when create_db_subnet_group is true."
  type        = list(string)
  default     = null
}

variable "create_security_group" {
  description = "Whether this module creates a security group for the DB instance."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID to create the security group in. Required when create_security_group is true."
  type        = string
  default     = null
}

variable "security_group_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the DB port. Only used when create_security_group is true. Left empty by default so no inbound access is opened unless explicitly requested."
  type        = list(string)
  default     = []
}

variable "security_group_ingress_security_group_ids" {
  description = "Security group IDs allowed to reach the DB port. Only used when create_security_group is true."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Existing security group IDs to attach to the DB instance, in addition to any security group this module creates."
  type        = list(string)
  default     = []
}

variable "port" {
  description = "Port the DB instance listens on. Null lets AWS use the engine default. Required (directly or via a recognized engine default) when create_security_group is true, since the security group rules need a concrete port."
  type        = number
  default     = null

  validation {
    condition     = var.port == null || (var.port >= 1150 && var.port <= 65535)
    error_message = "port must be null or between 1150 and 65535."
  }
}

variable "publicly_accessible" {
  description = "Whether the DB instance is publicly accessible."
  type        = bool
  default     = false
}

variable "network_type" {
  description = "Network type for the DB instance: IPV4 or DUAL. Null uses the AWS default."
  type        = string
  default     = null
}

### Availability / maintenance / lifecycle ###

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment for high availability."
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone to place the DB instance in. Ignored when multi_az is true."
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups. 0 disables automated backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "backup_window" {
  description = "Daily time range for automated backups, e.g. 04:00-05:00. Null lets AWS choose a window."
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance, e.g. sun:05:00-sun:06:00. Null lets AWS choose a window."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection, preventing accidental termination of the DB instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip creating a final snapshot when the DB instance is destroyed."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier_prefix" {
  description = "Prefix appended to var.identifier to build the final snapshot identifier. Ignored when skip_final_snapshot is true."
  type        = string
  default     = "final"
}

variable "copy_tags_to_snapshot" {
  description = "Whether to copy tags from the DB instance to snapshots."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately rather than during the next maintenance window."
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Whether minor engine upgrades are applied automatically during the maintenance window."
  type        = bool
  default     = true
}

variable "allow_major_version_upgrade" {
  description = "Whether major version upgrades are allowed."
  type        = bool
  default     = false
}

variable "ca_cert_identifier" {
  description = "Identifier of the CA certificate for the DB instance. Null uses the AWS default."
  type        = string
  default     = null
}

variable "character_set_name" {
  description = "Character set name for engines that support it (e.g. Oracle, SQL Server). Null uses the engine default."
  type        = string
  default     = null
}

variable "timezone" {
  description = "Timezone for engines that support it (e.g. SQL Server). Null uses the engine default."
  type        = string
  default     = null
}

variable "license_model" {
  description = "License model for engines that support it (e.g. Oracle, SQL Server). Null uses the engine default."
  type        = string
  default     = null
}

### Parameter / option groups ###

variable "create_db_parameter_group" {
  description = "Whether this module creates a DB parameter group. When false, parameter_group_name may reference an existing one."
  type        = bool
  default     = false
}

variable "parameter_group_name" {
  description = "Name of an existing DB parameter group to use when create_db_parameter_group is false. Null uses the engine's default parameter group."
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family, e.g. postgres16. Required when create_db_parameter_group is true."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Parameters to set in the module-managed DB parameter group. Only used when create_db_parameter_group is true."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "create_db_option_group" {
  description = "Whether this module creates a DB option group. When false, option_group_name may reference an existing one. Not all engines support option groups (e.g. Postgres does not)."
  type        = bool
  default     = false
}

variable "option_group_name" {
  description = "Name of an existing DB option group to use when create_db_option_group is false."
  type        = string
  default     = null
}

variable "major_engine_version" {
  description = "Major engine version for the option group, e.g. 8.0. Required when create_db_option_group is true."
  type        = string
  default     = null
}

variable "options" {
  description = "Options to set in the module-managed DB option group. Only used when create_db_option_group is true."
  type = list(object({
    option_name = string
    port        = optional(number)
    version     = optional(string)
    option_settings = optional(list(object({
      name  = string
      value = string
    })), [])
    db_security_group_memberships  = optional(list(string))
    vpc_security_group_memberships = optional(list(string))
  }))
  default = []
}

### Monitoring ###

variable "enable_enhanced_monitoring" {
  description = "Whether to enable RDS Enhanced Monitoring."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Interval, in seconds, between Enhanced Monitoring metric collections. Only used when enable_enhanced_monitoring is true."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "create_monitoring_role" {
  description = "Whether this module creates the IAM role used for Enhanced Monitoring. Only used when monitoring_role_arn is null and Enhanced Monitoring is enabled on the primary (enable_enhanced_monitoring) or on any entry in read_replicas."
  type        = bool
  default     = true
}

variable "monitoring_role_arn" {
  description = "ARN of an existing IAM role for Enhanced Monitoring. When null and create_monitoring_role is true, this module creates one."
  type        = string
  default     = null
}

variable "enable_performance_insights" {
  description = "Whether to enable Performance Insights."
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ARN used to encrypt Performance Insights data. Null uses the AWS-managed default key. Ignored when enable_performance_insights is false."
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Retention period in days for Performance Insights data: 7, 731, or a multiple of 31 up to 731. Ignored when enable_performance_insights is false."
  type        = number
  default     = 7

  validation {
    condition     = var.performance_insights_retention_period == 7 || var.performance_insights_retention_period == 731 || var.performance_insights_retention_period % 31 == 0
    error_message = "performance_insights_retention_period must be 7, 731, or a multiple of 31 up to 731."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of engine log types to export to CloudWatch Logs. Valid values depend on the engine (e.g. postgresql/upgrade for Postgres; audit/error/general/slowquery for MySQL/MariaDB)."
  type        = list(string)
  default     = []
}

variable "iam_database_authentication_enabled" {
  description = "Whether to enable IAM database authentication. Only supported by MySQL and PostgreSQL engines."
  type        = bool
  default     = false
}

### Read replicas ###

variable "read_replicas" {
  description = "Map of read replicas to create, keyed by a caller-chosen suffix appended to var.identifier. Fields left null fall back to the primary instance's corresponding setting where applicable (e.g. skip_final_snapshot defaults to var.skip_final_snapshot when unset)."
  type = map(object({
    instance_class               = optional(string)
    availability_zone            = optional(string)
    multi_az                     = optional(bool, false)
    publicly_accessible          = optional(bool, false)
    vpc_security_group_ids       = optional(list(string))
    parameter_group_name         = optional(string)
    auto_minor_version_upgrade   = optional(bool, true)
    monitoring_interval          = optional(number)
    performance_insights_enabled = optional(bool, false)
    skip_final_snapshot          = optional(bool)
    tags                         = optional(map(string), {})
  }))
  default = {}
}
