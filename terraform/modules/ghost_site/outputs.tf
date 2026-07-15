output "elastic_ip" {
  description = "Elastic IP attached to Ghost EC2 instance."
  value       = aws_eip.ghost.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.ghost.id
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

