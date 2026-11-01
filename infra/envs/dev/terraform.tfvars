# DEV - small, cheap, disposable.
environment = "dev"
aws_region  = "ap-south-1"

# Network: 2 AZs, one shared NAT gateway.
vpc_cidr           = "10.10.0.0/16"
azs                = ["ap-south-1a", "ap-south-1b"]
single_nat_gateway = true
enable_flow_logs   = false

# App: 0.25 vCPU / 0.5 GB, 1-2 tasks on Fargate Spot.
alb_deletion_protection = false
container_image         = "public.ecr.aws/nginx/nginx:1.27-alpine"
container_port          = 80
task_cpu                = 256
task_memory             = 512
desired_count           = 1
min_count               = 1
max_count               = 2
use_fargate_spot        = true
enable_execute_command  = true
container_insights      = false
log_retention_days      = 7

# Database: burstable single-AZ, short retention, easy to tear down.
db_instance_class               = "db.t4g.micro"
db_allocated_storage            = 20
db_max_allocated_storage        = 50
db_multi_az                     = false
db_backup_retention_days        = 1
db_deletion_protection          = false
db_skip_final_snapshot          = true
db_delete_automated_backups     = true
db_apply_immediately            = true
db_performance_insights_enabled = false
db_monitoring_interval          = 0
