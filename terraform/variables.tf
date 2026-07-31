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

