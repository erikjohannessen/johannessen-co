variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name."
  type        = string
  default     = "johannessen.co"
}

variable "ghost_image" {
  description = "Container image for Ghost."
  type        = string
  default     = "ghost:6-alpine"
  nullable    = false
}

variable "ssm_tunnel_instance_type" {
  description = "Instance type used for SSM database tunnel hosts."
  type        = string
  default     = "t3.nano"
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

variable "local_dev_ip" {
  description = "Optional public IPv4 address for local development access to MySQL (without /32)."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.local_dev_ip == null || can(regex(
      "^(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(?:\\.(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$",
      var.local_dev_ip
    ))
    error_message = "local_dev_ip must be a valid IPv4 address without CIDR suffix (for example 203.0.113.10)."
  }
}

variable "aws_role_name" {
  description = "Name of the IAM role used by GitHub Actions via OIDC."
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket name used for Terraform state storage."
  type        = string
}

