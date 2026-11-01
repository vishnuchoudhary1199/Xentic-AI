# PROD - highly available, protected, longer retention.
environment = "prod"
aws_region  = "ap-south-1"

# Network: 3 AZs, one NAT gateway per AZ, flow logs on.
vpc_cidr           = "10.20.0.0/16"
azs                = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
single_nat_gateway = false
enable_flow_logs   = true

# App: 1 vCPU / 2 GB, 3-10 tasks (one per AZ minimum) on on-demand Fargate.
# Set certificate_arn to an ACM certificate to serve HTTPS (HTTP then redirects).
# certificate_arn       = "arn:aws:acm:ap-south-1:123456789012:certificate/xxxx"
alb_deletion_protection = true
container_image         = "public.ecr.aws/nginx/nginx:1.27-alpine"
container_port          = 80
task_cpu                = 1024
task_memory             = 2048
desired_count           = 3
min_count               = 3
max_count               = 10
use_fargate_spot        = false
enable_execute_command  = false
container_insights      = true
log_retention_days      = 90

# Database: memory-optimised Graviton, Multi-AZ, 30-day PITR, protected.
db_instance_class               = "db.r6g.large"
db_allocated_storage            = 100
db_max_allocated_storage        = 500
db_multi_az                     = true
db_backup_retention_days        = 30
db_deletion_protection          = true
db_skip_final_snapshot          = false
db_delete_automated_backups     = false
db_apply_immediately            = false
db_performance_insights_enabled = true
db_monitoring_interval          = 60
