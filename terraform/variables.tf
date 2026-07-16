variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name."
  type        = string
  default     = "johannessen.co"
}

variable "ghost_instance_type" {
  description = "EC2 instance type for Ghost nodes."
  type        = string
  default     = "t3.small"
}

variable "db_password" {
  description = "MySQL password for Ghost databases."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{8,41}$", var.db_password))
    error_message = "db_password must be 8-41 alphanumeric characters."
  }
}

variable "ssh_allowed_ip" {
  description = "IP Address that is allowed to SSH into Ghost"
  type        = string
  default     = "127.0.0.1"
}

