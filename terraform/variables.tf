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
}

