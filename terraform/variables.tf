variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name."
  type        = string
  default     = "johannessen.co"
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

variable "github_actions_role_name" {
  description = "Name of the IAM role used by GitHub Actions via OIDC."
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket name used for Terraform state storage."
  type        = string
}

