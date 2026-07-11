output "elastic_ip" {
  description = "Elastic IP attached to Ghost EC2 instance."
  value       = aws_eip.ghost.public_ip
}

output "database_password" {
  description = "Generated MySQL password."
  value       = random_password.db_password.result
  sensitive   = true
}

