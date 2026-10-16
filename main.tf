data "aws_partition" "current" {}

locals {
  create_db_subnet_group = var.create_db_subnet_group
  create_security_group  = var.create_security_group
  create_parameter_group = var.create_db_parameter_group
  create_option_group    = var.create_db_option_group

  # A read replica may enable enhanced monitoring independently of the primary
  # (via read_replicas[*].monitoring_interval), so the shared monitoring role must
  # be created/resolved whenever ANY instance - primary or replica - needs one.
  read_replica_monitoring_intervals = {
    for k, v in var.read_replicas : k => coalesce(v.monitoring_interval, var.enable_enhanced_monitoring ? var.monitoring_interval : 0)
  }
  any_enhanced_monitoring_enabled = var.enable_enhanced_monitoring || anytrue([for interval in local.read_replica_monitoring_intervals : interval > 0])
  create_monitoring_role          = local.any_enhanced_monitoring_enabled && var.monitoring_role_arn == null && var.create_monitoring_role

  read_replica_skip_final_snapshot = {
    for k, v in var.read_replicas : k => coalesce(v.skip_final_snapshot, var.skip_final_snapshot)
  }

  # IAM role names are capped at 64 characters, and name_prefix reserves ~26 of those
  # for Terraform's generated suffix, leaving a ~38 character budget. Truncate long
  # identifiers so the prefix always fits regardless of var.identifier's length.
  monitoring_role_name_prefix = "${substr(var.identifier, 0, min(length(var.identifier), 29))}-rds-mon-"

  # AWS assigns the engine's default port automatically when the instance's `port`
  # argument is omitted, but the security group rules below need a concrete value
  # at plan time, so common engines get a fallback here.
  engine_default_ports = {
    mysql          = 3306
    mariadb        = 3306
    postgres       = 5432
    oracle-ee      = 1521
    oracle-ee-cdb  = 1521
    oracle-se2     = 1521
    oracle-se2-cdb = 1521
    sqlserver-ee   = 1433
    sqlserver-se   = 1433
    sqlserver-ex   = 1433
    sqlserver-web  = 1433
  }
  resolved_port = coalesce(var.port, lookup(local.engine_default_ports, var.engine, null))

  db_subnet_group_name = local.create_db_subnet_group ? aws_db_subnet_group.this[0].name : var.db_subnet_group_name
  vpc_security_group_ids = concat(
    local.create_security_group ? [aws_security_group.this[0].id] : [],
    var.vpc_security_group_ids,
  )
  parameter_group_name = local.create_parameter_group ? aws_db_parameter_group.this[0].name : var.parameter_group_name
  option_group_name    = local.create_option_group ? aws_db_option_group.this[0].name : var.option_group_name
  monitoring_role_arn = local.any_enhanced_monitoring_enabled ? (
    var.monitoring_role_arn != null ? var.monitoring_role_arn : try(aws_iam_role.enhanced_monitoring[0].arn, null)
  ) : null

  tags = var.tags
}

resource "aws_db_subnet_group" "this" {
  count = local.create_db_subnet_group ? 1 : 0

  name_prefix = "${var.identifier}-"
  description = "DB subnet group for ${var.identifier}"
  subnet_ids  = coalesce(var.subnet_ids, [])

  tags = local.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = length(coalesce(var.subnet_ids, [])) > 0
      error_message = "var.subnet_ids must contain at least one subnet when create_db_subnet_group is true."
    }
  }
}

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name_prefix = "${var.identifier}-"
  description = "Security group for RDS instance ${var.identifier}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.identifier}-sg" })

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.vpc_id != null
      error_message = "var.vpc_id must be set when create_security_group is true."
    }

    precondition {
      condition     = local.resolved_port != null
      error_message = "A port could not be resolved for security group rules. Set var.port explicitly, or use an engine with a known default port."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = local.create_security_group ? { for idx, cidr in var.security_group_ingress_cidr_blocks : tostring(idx) => cidr } : {}

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = each.value
  from_port         = local.resolved_port
  to_port           = local.resolved_port
  ip_protocol       = "tcp"
  description       = "Allow DB access from ${each.value}"

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "security_groups" {
  for_each = local.create_security_group ? { for idx, sg in var.security_group_ingress_security_group_ids : tostring(idx) => sg } : {}

  security_group_id            = aws_security_group.this[0].id
  referenced_security_group_id = each.value
  from_port                    = local.resolved_port
  to_port                      = local.resolved_port
  ip_protocol                  = "tcp"
  description                  = "Allow DB access from security group ${each.value}"

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = local.create_security_group ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"

  tags = local.tags
}

resource "aws_db_parameter_group" "this" {
  count = local.create_parameter_group ? 1 : 0

  name_prefix = "${var.identifier}-"
  family      = var.parameter_group_family
  description = "DB parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.parameter_group_family != null
      error_message = "var.parameter_group_family must be set when create_db_parameter_group is true."
    }
  }
}

resource "aws_db_option_group" "this" {
  count = local.create_option_group ? 1 : 0

  name_prefix              = "${var.identifier}-"
  option_group_description = "DB option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  dynamic "option" {
    for_each = var.options
    content {
      option_name = option.value.option_name
      port        = option.value.port
      version     = option.value.version

      dynamic "option_settings" {
        for_each = coalesce(option.value.option_settings, [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }

      db_security_group_memberships  = option.value.db_security_group_memberships
      vpc_security_group_memberships = option.value.vpc_security_group_memberships
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.major_engine_version != null
      error_message = "var.major_engine_version must be set when create_db_option_group is true."
    }
  }
}

data "aws_iam_policy_document" "monitoring_assume" {
  count = local.create_monitoring_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  count = local.create_monitoring_role ? 1 : 0

  name_prefix        = local.monitoring_role_name_prefix
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume[0].json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = local.create_monitoring_role ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  iops                  = var.iops
  storage_throughput    = var.storage_throughput
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  db_name                       = var.db_name
  username                      = var.username
  password                      = var.manage_master_user_password ? null : var.password
  manage_master_user_password   = var.manage_master_user_password ? true : null
  master_user_secret_kms_key_id = var.manage_master_user_password ? var.master_user_secret_kms_key_id : null

  port                   = local.resolved_port
  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = local.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  network_type           = var.network_type

  parameter_group_name = local.parameter_group_name
  option_group_name    = local.option_group_name
  character_set_name   = var.character_set_name
  timezone             = var.timezone
  license_model        = var.license_model

  multi_az          = var.multi_az
  availability_zone = var.multi_az ? null : var.availability_zone

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = var.copy_tags_to_snapshot
  apply_immediately       = var.apply_immediately

  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  allow_major_version_upgrade = var.allow_major_version_upgrade
  ca_cert_identifier          = var.ca_cert_identifier

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-${var.final_snapshot_identifier_prefix}"

  monitoring_interval = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = local.monitoring_role_arn

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.performance_insights_kms_key_id : null
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_period : null

  enabled_cloudwatch_logs_exports     = var.enabled_cloudwatch_logs_exports
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.manage_master_user_password || var.password != null
      error_message = "var.password must be set when var.manage_master_user_password is false."
    }

    precondition {
      condition     = !local.create_db_subnet_group || var.db_subnet_group_name == null
      error_message = "Do not set var.db_subnet_group_name when create_db_subnet_group is true; this module manages the subnet group."
    }

    precondition {
      condition     = !var.enable_enhanced_monitoring || local.monitoring_role_arn != null
      error_message = "When enable_enhanced_monitoring is true and create_monitoring_role is false, var.monitoring_role_arn must be set to an existing IAM role ARN."
    }

    precondition {
      condition     = !(var.manage_master_user_password && length(var.read_replicas) > 0)
      error_message = "AWS does not currently support creating read replicas from a source instance where manage_master_user_password is true (confirmed on both postgres and mysql; likely universal across engines). Set var.manage_master_user_password = false and supply var.password, or remove var.read_replicas."
    }
  }
}

resource "aws_db_instance" "read_replica" {
  for_each = var.read_replicas

  identifier          = "${var.identifier}-${each.key}"
  replicate_source_db = aws_db_instance.this.identifier

  instance_class         = coalesce(each.value.instance_class, var.instance_class)
  availability_zone      = each.value.multi_az ? null : each.value.availability_zone
  multi_az               = each.value.multi_az
  publicly_accessible    = each.value.publicly_accessible
  vpc_security_group_ids = coalesce(each.value.vpc_security_group_ids, local.vpc_security_group_ids)
  parameter_group_name   = each.value.parameter_group_name != null ? each.value.parameter_group_name : local.parameter_group_name

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  auto_minor_version_upgrade = each.value.auto_minor_version_upgrade
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = local.read_replica_skip_final_snapshot[each.key]
  final_snapshot_identifier  = local.read_replica_skip_final_snapshot[each.key] ? null : "${var.identifier}-${each.key}-${var.final_snapshot_identifier_prefix}"
  copy_tags_to_snapshot      = var.copy_tags_to_snapshot
  apply_immediately          = var.apply_immediately

  monitoring_interval = local.read_replica_monitoring_intervals[each.key]
  monitoring_role_arn = local.monitoring_role_arn

  performance_insights_enabled    = each.value.performance_insights_enabled
  performance_insights_kms_key_id = each.value.performance_insights_enabled ? var.performance_insights_kms_key_id : null

  tags = merge(local.tags, each.value.tags)

  lifecycle {
    precondition {
      condition     = local.read_replica_monitoring_intervals[each.key] == 0 || local.monitoring_role_arn != null
      error_message = "This read replica resolves to a monitoring_interval greater than 0, but no monitoring role ARN is available. Set var.monitoring_role_arn, or leave var.create_monitoring_role at its default (true) so this module can create one."
    }
  }
}
