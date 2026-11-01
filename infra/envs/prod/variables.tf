# General

variable "project" {
  description = "Project name, used as the resource name prefix and in tags."
  type        = string
  default     = "hotel-bookings"
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = var.environment == "prod"
    error_message = "This root module is the prod environment."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "offline_plan" {
  description = "Use dummy credentials and skip AWS API calls so `terraform plan -refresh=false` works without an AWS account. Review/CI only."
  type        = bool
  default     = false
}

# Network

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "azs" {
  description = "Availability zones to use."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across AZs (cheaper, not HA)."
  type        = bool
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs."
  type        = bool
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Application (ALB + ECS)

variable "certificate_arn" {
  description = "ACM certificate for HTTPS on the ALB. Null serves plain HTTP."
  type        = string
  default     = null
}

variable "alb_deletion_protection" {
  description = "Deletion protection for the ALB."
  type        = bool
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/"
}

variable "container_image" {
  description = "Application container image."
  type        = string
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64."
  type        = string
  default     = "X86_64"
}

variable "desired_count" {
  description = "Initial ECS task count."
  type        = number
}

variable "min_count" {
  description = "Minimum ECS task count (autoscaling)."
  type        = number
}

variable "max_count" {
  description = "Maximum ECS task count (autoscaling)."
  type        = number
}

variable "use_fargate_spot" {
  description = "Run tasks on Fargate Spot."
  type        = bool

  validation {
    condition     = !var.use_fargate_spot
    error_message = "Production tasks must not run on interruptible Fargate Spot."
  }
}

variable "enable_execute_command" {
  description = "Enable ECS Exec."
  type        = bool
}

variable "container_insights" {
  description = "Enable Container Insights."
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for app and flow logs."
  type        = number
}

# Database (RDS PostgreSQL)

variable "db_engine_major_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "bookings"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial storage (GiB)."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling ceiling (GiB)."
  type        = number
}

variable "db_multi_az" {
  description = "Multi-AZ standby."
  type        = bool

  validation {
    condition     = var.db_multi_az
    error_message = "Production databases must be Multi-AZ."
  }
}

variable "db_backup_retention_days" {
  description = "Automated backup / PITR retention in days."
  type        = number

  validation {
    condition     = var.db_backup_retention_days >= 7 && var.db_backup_retention_days <= 35
    error_message = "Production backup retention must be 7-35 days."
  }
}

variable "db_deletion_protection" {
  description = "RDS deletion protection."
  type        = bool

  validation {
    condition     = var.db_deletion_protection
    error_message = "Production databases must have deletion protection enabled."
  }
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is deleted."
  type        = bool

  validation {
    condition     = !var.db_skip_final_snapshot
    error_message = "Production must take a final snapshot on deletion."
  }
}

variable "db_delete_automated_backups" {
  description = "Delete automated backups with the instance."
  type        = bool
}

variable "db_apply_immediately" {
  description = "Apply DB changes immediately instead of in the maintenance window."
  type        = bool
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 disables)."
  type        = number
}
