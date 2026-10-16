# Complete usage: MySQL with a module-managed security group, custom parameter
# and option groups, Enhanced Monitoring, Performance Insights, CloudWatch log
# exports, and one read replica.
#
# Uses a Terraform-generated password (manage_master_user_password = false)
# rather than the AWS-managed master password, because AWS does not support
# creating read replicas from a source instance with an AWS-managed master
# password. The generated value lives in Terraform state - for a real
# deployment without read replicas, prefer manage_master_user_password = true
# (the module's default) so AWS manages the secret in Secrets Manager instead.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "random_password" "master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?"
}

module "rds" {
  source = "../../"

  identifier     = "example-complete"
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = "db.t4g.medium"

  allocated_storage     = 50
  max_allocated_storage = 200
  storage_type          = "gp3"

  username                    = "app_admin"
  manage_master_user_password = false
  password                    = random_password.master.result

  subnet_ids                         = data.aws_subnets.default.ids
  create_security_group              = true
  vpc_id                             = data.aws_vpc.default.id
  security_group_ingress_cidr_blocks = [data.aws_vpc.default.cidr_block]

  multi_az                = true
  backup_retention_period = 14
  deletion_protection     = false

  # This example uses a custom option group. AWS pins an option group to any
  # snapshot taken with it and refuses to delete the option group while that
  # snapshot exists, so a final snapshot here would block `terraform destroy`
  # from removing aws_db_option_group.this until the snapshot is deleted by
  # hand. Skipped for a disposable demo environment; a real deployment should
  # generally keep the final snapshot (the module's default).
  skip_final_snapshot = true

  create_db_parameter_group = true
  parameter_group_family    = "mysql8.4"
  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
  ]

  create_db_option_group = true
  major_engine_version   = "8.4"
  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"
    },
  ]

  enable_enhanced_monitoring = true
  monitoring_interval        = 60

  enable_performance_insights           = true
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  read_replicas = {
    replica1 = {
      instance_class      = "db.t4g.medium"
      skip_final_snapshot = true
    }
  }

  tags = {
    Environment = "example"
  }
}
