variable "name" {
  description = "Name prefix for all RDS resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database security group belongs to."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated data subnets for the DB subnet group (at least two AZs)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS subnet groups need subnets in at least two availability zones."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on the PostgreSQL port (the ECS task SG)."
  type        = list(string)
}

# Engine / sizing

variable "engine_major_version" {
  description = "PostgreSQL major version. Minor versions are upgraded automatically in the maintenance window."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class, e.g. db.t4g.micro (dev) or db.r6g.large (prod)."
  type        = string
}

variable "allocated_storage" {
  description = "Initial gp3 storage in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling in GiB."
  type        = number
}

variable "multi_az" {
  description = "Run a synchronous standby in a second AZ."
  type        = bool
}

variable "database_name" {
  description = "Name of the initial database."
  type        = string
  default     = "bookings"
}

variable "master_username" {
  description = "Master username. The password is generated and stored in Secrets Manager by RDS."
  type        = string
  default     = "bookings_admin"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for storage encryption. Null uses the AWS-managed aws/rds key."
  type        = string
  default     = null
}

# Backups / protection

variable "backup_retention_days" {
  description = "Days of automated backups / point-in-time recovery to keep (1-35)."
  type        = number

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "backup_window" {
  description = "Daily UTC backup window (must not overlap maintenance_window)."
  type        = string
  default     = "19:00-20:00" # 00:30-01:30 IST
}

variable "maintenance_window" {
  description = "Weekly UTC maintenance window."
  type        = string
  default     = "sun:20:30-sun:21:30"
}

variable "deletion_protection" {
  description = "Block DeleteDBInstance calls (and therefore terraform destroy)."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on deletion. Should be false anywhere data matters."
  type        = bool
}

variable "delete_automated_backups" {
  description = "Delete automated backups when the instance is deleted."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of in the maintenance window."
  type        = bool
  default     = false
}

# Observability

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "performance_insights_retention_days" {
  description = "Performance Insights retention (7 is free tier)."
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 disables)."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "log_min_duration_ms" {
  description = "Log queries slower than this many milliseconds (-1 disables)."
  type        = number
  default     = 500
}
