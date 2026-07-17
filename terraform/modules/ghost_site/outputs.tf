output "alb_dns_name" {
  description = "Public DNS name of the Ghost ALB."
  value       = aws_lb.ghost.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the Ghost ALB."
  value       = aws_lb.ghost.zone_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.ghost.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.ghost.name
}

output "db_instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.ghost.identifier
}

output "database_password" {
  description = "Configured MySQL password."
  value       = var.db_password
  sensitive   = true
}

