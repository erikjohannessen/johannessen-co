variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "aws_role_name" {
  description = "Name of the IAM role used by GitHub Actions via OIDC."
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket name used for Terraform state storage."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name used for SES domain sending identity."
  type        = string
}

variable "ses_mail_from" {
  description = "Optional default From address used by Ghost mail."
  type        = string
  default     = ""
}

variable "ghost_exports_bucket" {
  description = "Optional S3 bucket name where Ghost export JSON files are stored for imports."
  type        = string
  default     = ""
}

