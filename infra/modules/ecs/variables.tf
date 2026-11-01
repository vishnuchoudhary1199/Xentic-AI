variable "name" {
  description = "Name prefix for all ECS/ALB resources."
  type        = string
}

variable "aws_region" {
  description = "Region used by the awslogs log driver."
  type        = string
}

# Networking

variable "vpc_id" {
  description = "VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (at least two AZs)."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the Fargate tasks."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDRs of the data tier; tasks get egress to these on db_port only."
  type        = list(string)
  default     = []
}

variable "db_port" {
  description = "Database port that tasks may connect to."
  type        = number
  default     = 5432
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB listeners."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Load balancer

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, the ALB serves HTTPS and redirects HTTP to HTTPS."
  type        = string
  default     = null
}

variable "alb_deletion_protection" {
  description = "Prevent the ALB from being deleted."
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs. Null disables access logs."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "HTTP path the ALB target group health-checks."
  type        = string
  default     = "/"
}

# Task / service

variable "container_image" {
  description = "Container image for the application."
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 80
}

variable "container_environment" {
  description = "Plain-text environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = "Environment variables resolved from Secrets Manager at start: NAME => valueFrom (ARN, optionally with :json-key::)."
  type        = map(string)
  default     = {}
}

variable "secrets_manager_arns" {
  description = "Secret ARNs the execution role may read (must cover everything in container_secrets)."
  type        = list(string)
  default     = []
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "task_cpu must be a valid Fargate CPU value."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB (must be a valid pairing with task_cpu)."
  type        = number
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64 (Graviton, ~20% cheaper)."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "desired_count" {
  description = "Initial number of running tasks."
  type        = number
}

variable "min_count" {
  description = "Autoscaling minimum task count."
  type        = number
}

variable "max_count" {
  description = "Autoscaling maximum task count."
  type        = number
}

variable "cpu_target_percent" {
  description = "Target average CPU utilisation for autoscaling."
  type        = number
  default     = 60
}

variable "use_fargate_spot" {
  description = "Run tasks on FARGATE_SPOT (cheap, interruptible). Use for non-production only."
  type        = bool
  default     = false
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging running containers."
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch retention for application logs."
  type        = number
  default     = 30
}
