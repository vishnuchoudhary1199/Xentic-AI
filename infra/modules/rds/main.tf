# Private PostgreSQL instance. Password is managed by RDS in Secrets Manager,
# so it never ends up in code or state.

locals {
  port = 5432
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.name}-db"
  description = "Isolated data subnets for ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = { Name = "${var.name}-db-subnets" }
}

# Security group

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-rds-"
  description = "RDS: PostgreSQL from ECS tasks only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-rds-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  for_each = { for idx, sg in var.allowed_security_group_ids : tostring(idx) => sg }

  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from application tasks"
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
}

# No egress rules: the database never initiates outbound connections.

# Parameters

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg${var.engine_major_version}-"
  family      = "postgres${var.engine_major_version}"
  description = "Hardened parameters for ${var.name}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Log statements slower than this (ms) to spot missing indexes.
  parameter {
    name  = "log_min_duration_statement"
    value = tostring(var.log_min_duration_ms)
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Enhanced monitoring role (optional)

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name_prefix        = substr("${var.name}-rds-mon-", 0, 38)
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Instance

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  engine                      = "postgres"
  engine_version              = var.engine_major_version
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  instance_class              = var.instance_class
  parameter_group_name        = aws_db_parameter_group.this.name
  ca_cert_identifier          = "rds-ca-rsa2048-g1"

  db_name                             = var.database_name
  username                            = var.master_username
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  port                                = local.port

  # Storage
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Network - private only
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Backups and protection (per-environment)
  backup_retention_period  = var.backup_retention_days
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.delete_automated_backups
  deletion_protection      = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  # Timestamped so a second destroy/recreate cycle doesn't collide with an
  # older final snapshot. Set once at creation and then ignored (see lifecycle).
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-postgres-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  # Observability
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_days : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  apply_immediately = var.apply_immediately

  tags = { Name = "${var.name}-postgres" }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}
