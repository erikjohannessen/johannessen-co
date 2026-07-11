output "test_site_url" {
  description = "Test Ghost URL."
  value       = "http://test.johannessen.co"
}

output "prod_site_url" {
  description = "Production Ghost URL."
  value       = "http://blog.johannessen.co"
}

output "test_db_password" {
  description = "Generated test database password."
  value       = module.ghost_test.database_password
  sensitive   = true
}

output "prod_db_password" {
  description = "Generated production database password."
  value       = module.ghost_prod.database_password
  sensitive   = true
}

