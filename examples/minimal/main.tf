# Minimal usage: a single Postgres instance with an AWS-managed master password,
# a module-managed DB subnet group, and an existing (default VPC) security group.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

module "rds" {
  source = "../../"

  identifier     = "example-minimal"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20

  username = "app_admin"

  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [data.aws_security_group.default.id]
}
