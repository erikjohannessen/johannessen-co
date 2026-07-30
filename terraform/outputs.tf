output "hostname" {
  description = "Hostname for Ghost site."
  value       = module.ghost_site.hostname
}

output "alb_dns_name" {
  description = "ALB DNS name of the Ghost service."
  value       = module.ghost_site.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name of the Ghost service."
  value       = module.ghost_site.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name of the Ghost service."
  value       = module.ghost_site.ecs_service_name
}

output "db_instance_identifier" {
  description = "RDS identifier of the database."
  value       = module.ghost_site.db_instance_identifier
}

output "db_endpoint" {
  description = "RDS endpoint of the database."
  value       = module.ghost_site.db_endpoint
}

output "ssm_tunnel_instance_id" {
  description = "Instance ID of the SSM tunnel host."
  value       = module.ghost_site.ssm_tunnel_instance_id
}

output "db_password" {
  description = "Configured database password."
  value       = module.ghost_site.database_password
  sensitive   = true
}
