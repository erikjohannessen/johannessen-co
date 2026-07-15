variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "domain_name" {
  description = "Environment domain for Ghost URL."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Ghost."
  type        = string
}

variable "db_password" {
  description = "MySQL password for Ghost database."
  type        = string
  sensitive   = true
}

