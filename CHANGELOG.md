# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the module uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-27

### Added

- Standard RDS instance (`aws_db_instance`) for Postgres, MySQL, MariaDB, Oracle and SQL Server with secure defaults: storage encryption, deletion protection, an AWS-managed master password, no public access and a final snapshot on destroy.
- Final snapshots named `<identifier>-final-<random suffix>`, rotated whenever the instance is replaced so repeated destroys never collide, with an explicit `final_snapshot_identifier` override.
- Optional module-managed DB subnet group, security group, parameter group and option group, or bring your own.
- Security group rules keyed by CIDR or by a static caller-chosen name, with no egress unless `security_group_egress_cidr_blocks` is set.
- Module-managed CloudWatch log groups for `enabled_cloudwatch_logs_exports`, with a 30-day default retention and an optional KMS key.
- Enhanced Monitoring with a module-managed IAM role, attached only to instances whose own monitoring interval is above 0.
- Performance Insights and IAM database authentication toggles.
- Same-region read replicas via `read_replicas`, falling back to the primary's settings where unset.
- Minimal and complete examples, and unit tests against mock providers.

[1.0.0]: https://github.com/sudo-terraform-aws-modules/terraform-aws-rds/releases/tag/v1.0.0
