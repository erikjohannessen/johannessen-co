output "test_site_url" {
  description = "Test Ghost URL."
  value       = "http://test.johannessen.co"
}

output "prod_site_url" {
  description = "Production Ghost URL."
  value       = "http://blog.johannessen.co"
}

output "test_elastic_ip" {
  description = "Elastic IP of the test Ghost EC2 instance."
  value       = module.ghost_test.elastic_ip
}

output "prod_elastic_ip" {
  description = "Elastic IP of the production Ghost EC2 instance."
  value       = module.ghost_prod.elastic_ip
}

output "test_instance_id" {
  description = "EC2 instance ID of the test Ghost instance."
  value       = module.ghost_test.instance_id
}

output "prod_instance_id" {
  description = "EC2 instance ID of the production Ghost instance."
  value       = module.ghost_prod.instance_id
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

