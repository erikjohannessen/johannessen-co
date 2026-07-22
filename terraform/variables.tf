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

  validation {
    condition     = length(trimspace(var.ghost_image)) > 0
    error_message = "ghost_image must be a non-empty container image reference (e.g. ghost:6-alpine)."
  }
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

variable "aws_role_name" {
  description = "Name of the IAM role used by GitHub Actions via OIDC."
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket name used for Terraform state storage."
  type        = string
}

