output "test_site_url" {
  description = "Test Ghost URL."
  value       = "https://test.johannessen.co"
}

output "prod_site_url" {
  description = "Production Ghost URL."
  value       = "https://blog.johannessen.co"
}

output "test_alb_dns_name" {
  description = "ALB DNS name of the test Ghost service."
  value       = module.ghost_test.alb_dns_name
}

output "prod_alb_dns_name" {
  description = "ALB DNS name of the production Ghost service."
  value       = module.ghost_prod.alb_dns_name
}

output "test_ecs_cluster_name" {
  description = "ECS cluster name of the test Ghost service."
  value       = module.ghost_test.ecs_cluster_name
}

output "prod_ecs_cluster_name" {
  description = "ECS cluster name of the production Ghost service."
  value       = module.ghost_prod.ecs_cluster_name
}

output "test_ecs_service_name" {
  description = "ECS service name of the test Ghost service."
  value       = module.ghost_test.ecs_service_name
}

output "prod_ecs_service_name" {
  description = "ECS service name of the production Ghost service."
  value       = module.ghost_prod.ecs_service_name
}

output "test_db_instance_identifier" {
  description = "RDS identifier of the test database."
  value       = module.ghost_test.db_instance_identifier
}

output "prod_db_instance_identifier" {
  description = "RDS identifier of the production database."
  value       = module.ghost_prod.db_instance_identifier
}

output "test_db_password" {
  description = "Configured test database password."
  value       = module.ghost_test.database_password
  sensitive   = true
}

output "prod_db_password" {
  description = "Configured production database password."
  value       = module.ghost_prod.database_password
  sensitive   = true
}

