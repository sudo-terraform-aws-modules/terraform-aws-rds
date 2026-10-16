# terraform-aws-sudo-rds
A reusable Terraform module for provisioning a standard AWS RDS instance (`aws_db_instance`) — Postgres, MySQL, MariaDB, Oracle, or SQL Server — with sane, security-conscious defaults.

This module intentionally covers **standard RDS only**. Aurora clusters (`aws_rds_cluster`) have a different resource model and are out of scope here; use a separate `terraform-aws-sudo-rds-aurora` module for that.

## Features

- AWS-managed master password by default (`manage_master_user_password`), with an opt-out to a caller-supplied password.
- Storage encryption enabled by default; deletion protection enabled by default.
- Optional module-managed DB subnet group, security group (with explicit ingress/egress rules, no inline blocks), parameter group, and option group — or bring your own existing ones.
- Optional Enhanced Monitoring (with a module-managed IAM role), Performance Insights, CloudWatch log exports, and IAM database authentication.
- Optional same-region read replicas via a single `read_replicas` map. Note: AWS does not support creating read replicas from a source instance where `manage_master_user_password` is `true` — set it to `false` and supply `var.password` if you need read replicas (enforced by a plan-time precondition). Each replica can also set its own `skip_final_snapshot`, independent of the primary's `var.skip_final_snapshot` (falls back to it when left unset) — since a replica's data is redundant with the primary, it's common to skip its final snapshot even when the primary keeps one.

## Usage

```hcl
module "rds" {
  source = "github.com/sudo-terraform-aws-modules/terraform-aws-sudo-rds"

  identifier     = "my-app-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  username           = "app_admin"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [module.security_group.security_group_id]
}
```

See `examples/minimal` for the smallest working setup and `examples/complete` for parameter/option groups, Enhanced Monitoring, Performance Insights, log exports, and a read replica.

## Known AWS limitations

- **Read replicas + AWS-managed master password**: AWS does not support creating a read replica from a source instance where `manage_master_user_password` is `true`. Set it to `false` and supply `var.password` if `var.read_replicas` is non-empty (enforced by a plan-time precondition).
- **Custom option group + final snapshot**: AWS pins an option group to any snapshot (manual or final) taken while that option group was attached, and refuses to delete the option group while such a snapshot exists. If `create_db_option_group = true` and the primary keeps its final snapshot (`skip_final_snapshot = false`, the default), `terraform destroy` will delete the instance but then fail to delete `aws_db_option_group.this` — the option group stays until you manually delete the final snapshot. This is an AWS-side dependency Terraform cannot express or resolve for you, since the final snapshot is created outside of Terraform's state. Either accept that the option group outlives a `destroy` when you keep final snapshots, or set `skip_final_snapshot = true` in throwaway/CI environments where you don't need the snapshot.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_db_instance.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_option_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_option_group) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.security_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_iam_policy_document.monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Allocated storage size in GiB. | `number` | n/a | yes |
| <a name="input_allow_major_version_upgrade"></a> [allow\_major\_version\_upgrade](#input\_allow\_major\_version\_upgrade) | Whether major version upgrades are allowed. | `bool` | `false` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Whether modifications are applied immediately rather than during the next maintenance window. | `bool` | `false` | no |
| <a name="input_auto_minor_version_upgrade"></a> [auto\_minor\_version\_upgrade](#input\_auto\_minor\_version\_upgrade) | Whether minor engine upgrades are applied automatically during the maintenance window. | `bool` | `true` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone to place the DB instance in. Ignored when multi\_az is true. | `string` | `null` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Number of days to retain automated backups. 0 disables automated backups. | `number` | `7` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Daily time range for automated backups, e.g. 04:00-05:00. Null lets AWS choose a window. | `string` | `null` | no |
| <a name="input_ca_cert_identifier"></a> [ca\_cert\_identifier](#input\_ca\_cert\_identifier) | Identifier of the CA certificate for the DB instance. Null uses the AWS default. | `string` | `null` | no |
| <a name="input_character_set_name"></a> [character\_set\_name](#input\_character\_set\_name) | Character set name for engines that support it (e.g. Oracle, SQL Server). Null uses the engine default. | `string` | `null` | no |
| <a name="input_copy_tags_to_snapshot"></a> [copy\_tags\_to\_snapshot](#input\_copy\_tags\_to\_snapshot) | Whether to copy tags from the DB instance to snapshots. | `bool` | `true` | no |
| <a name="input_create_db_option_group"></a> [create\_db\_option\_group](#input\_create\_db\_option\_group) | Whether this module creates a DB option group. When false, option\_group\_name may reference an existing one. Not all engines support option groups (e.g. Postgres does not). | `bool` | `false` | no |
| <a name="input_create_db_parameter_group"></a> [create\_db\_parameter\_group](#input\_create\_db\_parameter\_group) | Whether this module creates a DB parameter group. When false, parameter\_group\_name may reference an existing one. | `bool` | `false` | no |
| <a name="input_create_db_subnet_group"></a> [create\_db\_subnet\_group](#input\_create\_db\_subnet\_group) | Whether this module creates a DB subnet group. When false, db\_subnet\_group\_name must reference an existing one. | `bool` | `true` | no |
| <a name="input_create_monitoring_role"></a> [create\_monitoring\_role](#input\_create\_monitoring\_role) | Whether this module creates the IAM role used for Enhanced Monitoring. Only used when monitoring\_role\_arn is null and Enhanced Monitoring is enabled on the primary (enable\_enhanced\_monitoring) or on any entry in read\_replicas. | `bool` | `true` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Whether this module creates a security group for the DB instance. | `bool` | `false` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Name of the initial database to create. Null skips creating an initial database. | `string` | `null` | no |
| <a name="input_db_subnet_group_name"></a> [db\_subnet\_group\_name](#input\_db\_subnet\_group\_name) | Name of an existing DB subnet group to use when create\_db\_subnet\_group is false. | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection, preventing accidental termination of the DB instance. | `bool` | `true` | no |
| <a name="input_enable_enhanced_monitoring"></a> [enable\_enhanced\_monitoring](#input\_enable\_enhanced\_monitoring) | Whether to enable RDS Enhanced Monitoring. | `bool` | `false` | no |
| <a name="input_enable_performance_insights"></a> [enable\_performance\_insights](#input\_enable\_performance\_insights) | Whether to enable Performance Insights. | `bool` | `false` | no |
| <a name="input_enabled_cloudwatch_logs_exports"></a> [enabled\_cloudwatch\_logs\_exports](#input\_enabled\_cloudwatch\_logs\_exports) | List of engine log types to export to CloudWatch Logs. Valid values depend on the engine (e.g. postgresql/upgrade for Postgres; audit/error/general/slowquery for MySQL/MariaDB). | `list(string)` | `[]` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | Database engine to use, e.g. postgres, mysql, mariadb, oracle-se2, sqlserver-ex. | `string` | n/a | yes |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Engine version to use. When null, AWS selects the current default version at creation time. | `string` | `null` | no |
| <a name="input_final_snapshot_identifier_prefix"></a> [final\_snapshot\_identifier\_prefix](#input\_final\_snapshot\_identifier\_prefix) | Prefix appended to var.identifier to build the final snapshot identifier. Ignored when skip\_final\_snapshot is true. | `string` | `"final"` | no |
| <a name="input_iam_database_authentication_enabled"></a> [iam\_database\_authentication\_enabled](#input\_iam\_database\_authentication\_enabled) | Whether to enable IAM database authentication. Only supported by MySQL and PostgreSQL engines. | `bool` | `false` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | RDS instance identifier. Must start with a letter, contain only alphanumeric characters and hyphens, not end with a hyphen, and not contain two consecutive hyphens. | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Instance class for the DB instance, e.g. db.t4g.micro. | `string` | n/a | yes |
| <a name="input_iops"></a> [iops](#input\_iops) | Provisioned IOPS. Only applicable to io1/io2 storage, or gp3 above the baseline. | `number` | `null` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | ARN of the KMS key used to encrypt storage. Null uses the AWS-managed default RDS key. | `string` | `null` | no |
| <a name="input_license_model"></a> [license\_model](#input\_license\_model) | License model for engines that support it (e.g. Oracle, SQL Server). Null uses the engine default. | `string` | `null` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Weekly time range for maintenance, e.g. sun:05:00-sun:06:00. Null lets AWS choose a window. | `string` | `null` | no |
| <a name="input_major_engine_version"></a> [major\_engine\_version](#input\_major\_engine\_version) | Major engine version for the option group, e.g. 8.0. Required when create\_db\_option\_group is true. | `string` | `null` | no |
| <a name="input_manage_master_user_password"></a> [manage\_master\_user\_password](#input\_manage\_master\_user\_password) | Whether AWS should generate and manage the master password in Secrets Manager. When false, var.password must be supplied. | `bool` | `true` | no |
| <a name="input_master_user_secret_kms_key_id"></a> [master\_user\_secret\_kms\_key\_id](#input\_master\_user\_secret\_kms\_key\_id) | KMS key ARN used to encrypt the AWS-managed master user secret. Null uses the default Secrets Manager key. Ignored when manage\_master\_user\_password is false. | `string` | `null` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Upper limit in GiB for RDS storage autoscaling. Null disables storage autoscaling. | `number` | `null` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | Interval, in seconds, between Enhanced Monitoring metric collections. Only used when enable\_enhanced\_monitoring is true. | `number` | `60` | no |
| <a name="input_monitoring_role_arn"></a> [monitoring\_role\_arn](#input\_monitoring\_role\_arn) | ARN of an existing IAM role for Enhanced Monitoring. When null and create\_monitoring\_role is true, this module creates one. | `string` | `null` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Whether to enable Multi-AZ deployment for high availability. | `bool` | `false` | no |
| <a name="input_network_type"></a> [network\_type](#input\_network\_type) | Network type for the DB instance: IPV4 or DUAL. Null uses the AWS default. | `string` | `null` | no |
| <a name="input_option_group_name"></a> [option\_group\_name](#input\_option\_group\_name) | Name of an existing DB option group to use when create\_db\_option\_group is false. | `string` | `null` | no |
| <a name="input_options"></a> [options](#input\_options) | Options to set in the module-managed DB option group. Only used when create\_db\_option\_group is true. | <pre>list(object({<br/>    option_name = string<br/>    port        = optional(number)<br/>    version     = optional(string)<br/>    option_settings = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/>    db_security_group_memberships  = optional(list(string))<br/>    vpc_security_group_memberships = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_parameter_group_family"></a> [parameter\_group\_family](#input\_parameter\_group\_family) | Parameter group family, e.g. postgres16. Required when create\_db\_parameter\_group is true. | `string` | `null` | no |
| <a name="input_parameter_group_name"></a> [parameter\_group\_name](#input\_parameter\_group\_name) | Name of an existing DB parameter group to use when create\_db\_parameter\_group is false. Null uses the engine's default parameter group. | `string` | `null` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | Parameters to set in the module-managed DB parameter group. Only used when create\_db\_parameter\_group is true. | <pre>list(object({<br/>    name         = string<br/>    value        = string<br/>    apply_method = optional(string, "immediate")<br/>  }))</pre> | `[]` | no |
| <a name="input_password"></a> [password](#input\_password) | Master password. Required only when manage\_master\_user\_password is false. Never store this in plain tfvars; source it from a secrets manager at runtime. | `string` | `null` | no |
| <a name="input_performance_insights_kms_key_id"></a> [performance\_insights\_kms\_key\_id](#input\_performance\_insights\_kms\_key\_id) | KMS key ARN used to encrypt Performance Insights data. Null uses the AWS-managed default key. Ignored when enable\_performance\_insights is false. | `string` | `null` | no |
| <a name="input_performance_insights_retention_period"></a> [performance\_insights\_retention\_period](#input\_performance\_insights\_retention\_period) | Retention period in days for Performance Insights data: 7, 731, or a multiple of 31 up to 731. Ignored when enable\_performance\_insights is false. | `number` | `7` | no |
| <a name="input_port"></a> [port](#input\_port) | Port the DB instance listens on. Null lets AWS use the engine default. Required (directly or via a recognized engine default) when create\_security\_group is true, since the security group rules need a concrete port. | `number` | `null` | no |
| <a name="input_publicly_accessible"></a> [publicly\_accessible](#input\_publicly\_accessible) | Whether the DB instance is publicly accessible. | `bool` | `false` | no |
| <a name="input_read_replicas"></a> [read\_replicas](#input\_read\_replicas) | Map of read replicas to create, keyed by a caller-chosen suffix appended to var.identifier. Fields left null fall back to the primary instance's corresponding setting where applicable (e.g. skip\_final\_snapshot defaults to var.skip\_final\_snapshot when unset). | <pre>map(object({<br/>    instance_class               = optional(string)<br/>    availability_zone            = optional(string)<br/>    multi_az                     = optional(bool, false)<br/>    publicly_accessible          = optional(bool, false)<br/>    vpc_security_group_ids       = optional(list(string))<br/>    parameter_group_name         = optional(string)<br/>    auto_minor_version_upgrade   = optional(bool, true)<br/>    monitoring_interval          = optional(number)<br/>    performance_insights_enabled = optional(bool, false)<br/>    skip_final_snapshot          = optional(bool)<br/>    tags                         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_security_group_ingress_cidr_blocks"></a> [security\_group\_ingress\_cidr\_blocks](#input\_security\_group\_ingress\_cidr\_blocks) | CIDR blocks allowed to reach the DB port. Only used when create\_security\_group is true. Left empty by default so no inbound access is opened unless explicitly requested. | `list(string)` | `[]` | no |
| <a name="input_security_group_ingress_security_group_ids"></a> [security\_group\_ingress\_security\_group\_ids](#input\_security\_group\_ingress\_security\_group\_ids) | Security group IDs allowed to reach the DB port. Only used when create\_security\_group is true. | `list(string)` | `[]` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Whether to skip creating a final snapshot when the DB instance is destroyed. | `bool` | `false` | no |
| <a name="input_storage_encrypted"></a> [storage\_encrypted](#input\_storage\_encrypted) | Whether the DB storage is encrypted at rest. | `bool` | `true` | no |
| <a name="input_storage_throughput"></a> [storage\_throughput](#input\_storage\_throughput) | Provisioned storage throughput in MiBps. Only applicable to gp3 storage. | `number` | `null` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Storage type for the DB instance. | `string` | `"gp3"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the DB subnet group. Required when create\_db\_subnet\_group is true. | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_timezone"></a> [timezone](#input\_timezone) | Timezone for engines that support it (e.g. SQL Server). Null uses the engine default. | `string` | `null` | no |
| <a name="input_username"></a> [username](#input\_username) | Master username for the DB instance. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to create the security group in. Required when create\_security\_group is true. | `string` | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Existing security group IDs to attach to the DB instance, in addition to any security group this module creates. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | Hostname of the DB instance. |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the DB instance. |
| <a name="output_db_subnet_group_id"></a> [db\_subnet\_group\_id](#output\_db\_subnet\_group\_id) | ID of the DB subnet group, or null when create\_db\_subnet\_group is false. |
| <a name="output_db_subnet_group_name"></a> [db\_subnet\_group\_name](#output\_db\_subnet\_group\_name) | Name of the DB subnet group in use, whether module-managed or caller-supplied. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Connection endpoint of the DB instance, in address:port format. |
| <a name="output_enhanced_monitoring_iam_role_arn"></a> [enhanced\_monitoring\_iam\_role\_arn](#output\_enhanced\_monitoring\_iam\_role\_arn) | ARN of the IAM role used for Enhanced Monitoring, or null when not applicable. |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id) | Route 53 hosted zone ID of the DB instance. |
| <a name="output_id"></a> [id](#output\_id) | ID of the DB instance. |
| <a name="output_identifier"></a> [identifier](#output\_identifier) | Identifier of the DB instance. |
| <a name="output_master_user_secret"></a> [master\_user\_secret](#output\_master\_user\_secret) | Details of the AWS-managed master user secret (secret\_arn, kms\_key\_id, secret\_status), or null when manage\_master\_user\_password is false. |
| <a name="output_option_group_name"></a> [option\_group\_name](#output\_option\_group\_name) | Name of the DB option group in use, whether module-managed or caller-supplied, or null when neither is set. |
| <a name="output_parameter_group_name"></a> [parameter\_group\_name](#output\_parameter\_group\_name) | Name of the DB parameter group in use, whether module-managed or caller-supplied, or null when neither is set. |
| <a name="output_port"></a> [port](#output\_port) | Port the DB instance listens on. |
| <a name="output_read_replica_arns"></a> [read\_replica\_arns](#output\_read\_replica\_arns) | Map of read replica keys to their DB instance ARNs. |
| <a name="output_read_replica_endpoints"></a> [read\_replica\_endpoints](#output\_read\_replica\_endpoints) | Map of read replica keys to their connection endpoints. |
| <a name="output_read_replica_ids"></a> [read\_replica\_ids](#output\_read\_replica\_ids) | Map of read replica keys to their DB instance IDs. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | RDS resource ID of the DB instance (used for IAM database authentication ARNs). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group created by this module, or null when create\_security\_group is false. |
| <a name="output_status"></a> [status](#output\_status) | Current status of the DB instance. |
| <a name="output_username"></a> [username](#output\_username) | Master username of the DB instance. |
<!-- END_TF_DOCS -->
