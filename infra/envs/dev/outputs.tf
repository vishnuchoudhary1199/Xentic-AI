output "alb_url" {
  description = "Public URL of the application."
  value       = "${var.certificate_arn == null ? "http" : "https"}://${module.ecs.alb_dns_name}"
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "rds_endpoint" {
  description = "Private RDS endpoint (reachable only from the ECS tasks)."
  value       = module.rds.endpoint
}

output "rds_master_secret_arn" {
  description = "Secrets Manager ARN of the RDS master credentials."
  value       = module.rds.master_user_secret_arn
}

output "security_group_ids" {
  description = "Security groups for each tier."
  value = {
    alb = module.ecs.alb_security_group_id
    ecs = module.ecs.ecs_security_group_id
    rds = module.rds.security_group_id
  }
}
