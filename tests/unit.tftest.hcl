mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/unit-test-rds-mon"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }
}

mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "abcd1234"
    }
  }
}

variables {
  identifier        = "unit-test"
  engine            = "postgres"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  username          = "app_admin"
  subnet_ids        = ["subnet-0123456789abcdef0"]
}

### Defaults ###

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.deletion_protection
    error_message = "Storage encryption and deletion protection must default to on."
  }

  assert {
    condition     = !aws_db_instance.this.publicly_accessible
    error_message = "The instance must not be publicly accessible by default."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.password == null
    error_message = "The master password must default to AWS-managed, with no password in config."
  }

  assert {
    condition     = !aws_db_instance.this.skip_final_snapshot && length(random_id.final_snapshot) == 1
    error_message = "A final snapshot must be taken by default, with a generated suffix."
  }

  assert {
    condition     = aws_db_instance.this.storage_type == "gp3" && aws_db_instance.this.backup_retention_period == 7 && aws_db_instance.this.copy_tags_to_snapshot
    error_message = "Storage and backup defaults changed."
  }

  assert {
    condition     = aws_db_instance.this.port == 5432
    error_message = "The engine default port must be resolved for postgres."
  }

  assert {
    condition     = aws_db_instance.this.monitoring_interval == 0 && length(aws_iam_role.enhanced_monitoring) == 0
    error_message = "Enhanced Monitoring and its IAM role must be off by default."
  }

  assert {
    condition     = length(aws_db_subnet_group.this) == 1 && length(aws_security_group.this) == 0
    error_message = "Only the DB subnet group should be module-managed by default."
  }

  assert {
    condition     = length(aws_db_parameter_group.this) == 0 && length(aws_db_option_group.this) == 0
    error_message = "Parameter and option groups must not be created unless asked for."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0 && length(aws_db_instance.read_replica) == 0
    error_message = "No log groups or replicas should exist without exports or read_replicas."
  }
}

run "null_collections_fall_back_to_defaults" {
  command = plan

  variables {
    tags                                   = null
    vpc_security_group_ids                 = null
    security_group_ingress_cidr_blocks     = null
    security_group_ingress_security_groups = null
    security_group_egress_cidr_blocks      = null
    parameters                             = null
    options                                = null
    enabled_cloudwatch_logs_exports        = null
    read_replicas                          = null
  }

  assert {
    condition     = length(aws_db_instance.read_replica) == 0
    error_message = "A null collection must behave like its empty default."
  }
}

### Final snapshot naming ###

run "generated_final_snapshot_identifier" {
  command = apply

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "unit-test-final-abcd1234"
    error_message = "The final snapshot identifier must be <identifier>-final-<random suffix>."
  }
}

run "explicit_final_snapshot_identifier" {
  command = plan

  variables {
    final_snapshot_identifier = "unit-test-keep"
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "unit-test-keep" && length(random_id.final_snapshot) == 0
    error_message = "An explicit final_snapshot_identifier must be used as-is, with no random suffix."
  }
}

run "skip_final_snapshot" {
  command = plan

  variables {
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == null && length(random_id.final_snapshot) == 0
    error_message = "No final snapshot identifier should be set when skip_final_snapshot is true."
  }
}

run "invalid_final_snapshot_identifier" {
  command = plan

  variables {
    final_snapshot_identifier = "bad--name"
  }

  expect_failures = [var.final_snapshot_identifier]
}

### Read replicas ###

run "read_replica_fallbacks" {
  command = apply

  variables {
    manage_master_user_password = false
    password                    = "unit-test-password"
    vpc_security_group_ids      = ["sg-primary"]
    parameter_group_name        = "primary-params"
    tags                        = { Team = "data" }

    read_replicas = {
      r1 = {}
      r2 = {
        instance_class         = "db.t4g.small"
        vpc_security_group_ids = ["sg-replica"]
        parameter_group_name   = "replica-params"
        skip_final_snapshot    = true
        tags                   = { Role = "reporting" }
      }
      r3 = {
        final_snapshot_identifier = "r3-keep"
      }
    }
  }

  assert {
    condition     = aws_db_instance.read_replica["r1"].identifier == "unit-test-r1" && aws_db_instance.read_replica["r1"].replicate_source_db == "unit-test"
    error_message = "Replicas must be named <identifier>-<key> and replicate from the primary."
  }

  assert {
    condition     = aws_db_instance.read_replica["r1"].instance_class == "db.t4g.micro" && aws_db_instance.read_replica["r2"].instance_class == "db.t4g.small"
    error_message = "instance_class must fall back to the primary's unless overridden."
  }

  assert {
    condition     = aws_db_instance.read_replica["r1"].vpc_security_group_ids == toset(["sg-primary"]) && aws_db_instance.read_replica["r2"].vpc_security_group_ids == toset(["sg-replica"])
    error_message = "vpc_security_group_ids must fall back to the primary's unless overridden."
  }

  assert {
    condition     = aws_db_instance.read_replica["r1"].parameter_group_name == "primary-params" && aws_db_instance.read_replica["r2"].parameter_group_name == "replica-params"
    error_message = "parameter_group_name must fall back to the primary's unless overridden."
  }

  assert {
    condition = (
      aws_db_instance.read_replica["r1"].final_snapshot_identifier == "unit-test-r1-final-abcd1234" &&
      aws_db_instance.read_replica["r2"].final_snapshot_identifier == null &&
      aws_db_instance.read_replica["r3"].final_snapshot_identifier == "r3-keep" &&
      keys(random_id.read_replica_final_snapshot) == ["r1"]
    )
    error_message = "Replica final snapshots must inherit skip_final_snapshot, and only get a random suffix when no name is given."
  }

  assert {
    condition     = aws_db_instance.read_replica["r2"].tags == tomap({ Team = "data", Role = "reporting" })
    error_message = "Replica tags must be merged over the module tags."
  }
}

run "read_replica_monitoring_without_primary" {
  command = plan

  variables {
    manage_master_user_password = false
    password                    = "unit-test-password"

    read_replicas = {
      r1 = { monitoring_interval = 30 }
      r2 = {}
    }
  }

  assert {
    condition     = aws_db_instance.this.monitoring_interval == 0 && aws_db_instance.read_replica["r2"].monitoring_interval == 0
    error_message = "The primary and replicas without their own interval must keep monitoring off."
  }

  assert {
    condition     = aws_db_instance.read_replica["r1"].monitoring_interval == 30 && length(aws_iam_role.enhanced_monitoring) == 1
    error_message = "A replica enabling monitoring on its own must get the shared monitoring role."
  }
}

run "primary_monitoring_interval_zero_creates_no_role" {
  command = plan

  variables {
    enable_enhanced_monitoring = true
    monitoring_interval        = 0
  }

  assert {
    condition     = length(aws_iam_role.enhanced_monitoring) == 0
    error_message = "No monitoring role should be created when the resolved interval is 0."
  }
}

### Preconditions ###

run "password_required_when_not_managed" {
  command = plan

  variables {
    manage_master_user_password = false
  }

  expect_failures = [aws_db_instance.this]
}

run "read_replicas_require_unmanaged_password" {
  command = plan

  variables {
    read_replicas = { r1 = {} }
  }

  expect_failures = [aws_db_instance.this]
}

run "subnet_group_name_conflicts_with_managed_group" {
  command = plan

  variables {
    db_subnet_group_name = "existing"
  }

  expect_failures = [aws_db_instance.this]
}

run "managed_subnet_group_requires_subnets" {
  command = plan

  variables {
    subnet_ids = []
  }

  expect_failures = [aws_db_subnet_group.this]
}

run "enhanced_monitoring_requires_role" {
  command = plan

  variables {
    enable_enhanced_monitoring = true
    create_monitoring_role     = false
  }

  expect_failures = [aws_db_instance.this]
}

run "replica_monitoring_requires_role" {
  command = plan

  variables {
    manage_master_user_password = false
    password                    = "unit-test-password"
    create_monitoring_role      = false
    read_replicas               = { r1 = { monitoring_interval = 30 } }
  }

  expect_failures = [aws_db_instance.read_replica]
}

run "security_group_requires_vpc_id" {
  command = plan

  variables {
    create_security_group = true
  }

  expect_failures = [aws_security_group.this]
}

run "security_group_requires_resolvable_port" {
  command = plan

  variables {
    engine                = "db2-se"
    create_security_group = true
    vpc_id                = "vpc-0123456789abcdef0"
  }

  expect_failures = [aws_security_group.this]
}

run "parameter_group_requires_family" {
  command = plan

  variables {
    create_db_parameter_group = true
  }

  expect_failures = [aws_db_parameter_group.this]
}

run "option_group_requires_major_engine_version" {
  command = plan

  variables {
    engine                 = "mysql"
    create_db_option_group = true
  }

  expect_failures = [aws_db_option_group.this]
}

### Security group ###

run "security_group_rules" {
  command = plan

  variables {
    create_security_group                  = true
    vpc_id                                 = "vpc-0123456789abcdef0"
    security_group_ingress_cidr_blocks     = ["10.1.0.0/16", "10.0.0.0/16"]
    security_group_ingress_security_groups = { app = "sg-app", bastion = "sg-bastion" }
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.cidr) == ["10.0.0.0/16", "10.1.0.0/16"]
    error_message = "CIDR ingress rules must be keyed by the CIDR, not list position."
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.security_groups) == ["app", "bastion"]
    error_message = "Security group ingress rules must be keyed by the caller's static names."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.cidr["10.0.0.0/16"].from_port == 5432 && aws_vpc_security_group_ingress_rule.cidr["10.0.0.0/16"].ip_protocol == "tcp"
    error_message = "Ingress must be limited to the DB port over TCP."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.cidr) == 0
    error_message = "No egress must be opened by default."
  }
}

run "security_group_explicit_egress" {
  command = plan

  variables {
    create_security_group             = true
    vpc_id                            = "vpc-0123456789abcdef0"
    security_group_egress_cidr_blocks = ["10.0.0.0/16"]
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.cidr["10.0.0.0/16"].cidr_ipv4 == "10.0.0.0/16"
    error_message = "Requested egress CIDRs must get a rule keyed by the CIDR."
  }
}

run "invalid_ingress_cidr" {
  command = plan

  variables {
    security_group_ingress_cidr_blocks = ["10.0.0.0/33"]
  }

  expect_failures = [var.security_group_ingress_cidr_blocks]
}

run "ipv6_egress_cidr_rejected" {
  command = plan

  variables {
    security_group_egress_cidr_blocks = ["::/0"]
  }

  expect_failures = [var.security_group_egress_cidr_blocks]
}

### CloudWatch log groups ###

run "log_groups_created_for_exports" {
  command = plan

  variables {
    enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  }

  assert {
    condition     = aws_cloudwatch_log_group.this["postgresql"].name == "/aws/rds/instance/unit-test/postgresql"
    error_message = "Log groups must use the name RDS exports to."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this["upgrade"].retention_in_days == 30 && aws_cloudwatch_log_group.this["upgrade"].kms_key_id == null
    error_message = "Log groups must default to 30-day retention and no explicit KMS key."
  }
}

run "log_group_retention_and_kms" {
  command = plan

  variables {
    enabled_cloudwatch_logs_exports        = ["postgresql"]
    cloudwatch_log_group_retention_in_days = 7
    cloudwatch_log_group_kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/unit-test"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this["postgresql"].retention_in_days == 7 && aws_cloudwatch_log_group.this["postgresql"].kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/unit-test"
    error_message = "Caller-supplied retention and KMS key must be applied."
  }
}

run "log_groups_opt_out" {
  command = plan

  variables {
    enabled_cloudwatch_logs_exports = ["postgresql"]
    create_cloudwatch_log_group     = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "No log groups should be created when create_cloudwatch_log_group is false."
  }
}

run "invalid_log_retention" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 0
  }

  expect_failures = [var.cloudwatch_log_group_retention_in_days]
}

### Input validation ###

run "invalid_identifier" {
  command = plan

  variables {
    identifier = "1-bad"
  }

  expect_failures = [var.identifier]
}

run "performance_insights_retention_too_low" {
  command = plan

  variables {
    performance_insights_retention_period = 0
  }

  expect_failures = [var.performance_insights_retention_period]
}

run "performance_insights_retention_too_high" {
  command = plan

  variables {
    performance_insights_retention_period = 744
  }

  expect_failures = [var.performance_insights_retention_period]
}

run "performance_insights_retention_multiple_of_31" {
  command = plan

  variables {
    enable_performance_insights           = true
    performance_insights_retention_period = 62
  }

  assert {
    condition     = aws_db_instance.this.performance_insights_retention_period == 62
    error_message = "A multiple of 31 within range must be accepted."
  }
}
