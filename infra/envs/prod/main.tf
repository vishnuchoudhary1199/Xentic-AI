locals {
  name = "${var.project}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name                     = local.name
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  single_nat_gateway       = var.single_nat_gateway
  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = var.log_retention_days
}

module "ecs" {
  source = "../../modules/ecs"

  name       = local.name
  aws_region = var.aws_region

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  db_subnet_cidrs       = module.network.data_subnet_cidrs
  db_port               = 5432
  allowed_ingress_cidrs = var.allowed_ingress_cidrs

  certificate_arn         = var.certificate_arn
  alb_deletion_protection = var.alb_deletion_protection
  health_check_path       = var.health_check_path

  container_image  = var.container_image
  container_port   = var.container_port
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory
  cpu_architecture = var.cpu_architecture
  desired_count    = var.desired_count
  min_count        = var.min_count
  max_count        = var.max_count
  use_fargate_spot = var.use_fargate_spot

  enable_execute_command = var.enable_execute_command
  container_insights     = var.container_insights
  log_retention_days     = var.log_retention_days

  container_environment = {
    APP_ENV = var.environment
    DB_HOST = module.rds.endpoint
    DB_PORT = tostring(module.rds.port)
    DB_NAME = module.rds.database_name
  }

  # Credentials are injected by ECS from the RDS-managed secret at task start.
  container_secrets = {
    DB_USERNAME = "${module.rds.master_user_secret_arn}:username::"
    DB_PASSWORD = "${module.rds.master_user_secret_arn}:password::"
  }
  secrets_manager_arns = [module.rds.master_user_secret_arn]
}

module "rds" {
  source = "../../modules/rds"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.data_subnet_ids
  allowed_security_group_ids = [module.ecs.ecs_security_group_id]

  engine_major_version  = var.db_engine_major_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  multi_az              = var.db_multi_az
  database_name         = var.db_name

  backup_retention_days    = var.db_backup_retention_days
  deletion_protection      = var.db_deletion_protection
  skip_final_snapshot      = var.db_skip_final_snapshot
  delete_automated_backups = var.db_delete_automated_backups
  apply_immediately        = var.db_apply_immediately

  performance_insights_enabled = var.db_performance_insights_enabled
  monitoring_interval          = var.db_monitoring_interval
}
