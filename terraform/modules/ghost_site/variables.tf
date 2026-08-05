variable "environment" {
  description = "Environment for this Ghost site."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name."
  type        = string
}

variable "subdomain" {
  description = "Subdomain where Ghost is hosted."
  type        = string
}

variable "db_password" {
  description = "MySQL password for Ghost database."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{8,41}$", var.db_password))
    error_message = "db_password must be 8-41 alphanumeric characters."
  }
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
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

variable "ssm_tunnel_instance_type" {
  description = "Instance type used for SSM database tunnel hosts."
  type        = string
  default     = "t3.nano"
}

variable "ssm_tunnel_instance_profile" {
  description = "IAM Instance Profile used when connecting to SSM tunnel hosts."
  type        = string
}

variable "ses_smtp_username" {
  description = "SES SMTP username used by Ghost mail transport."
  type        = string
}

variable "ses_smtp_password" {
  description = "SES SMTP password used by Ghost mail transport."
  type        = string
  sensitive   = true
}

variable "ses_smtp_host" {
  description = "SES SMTP host used by Ghost mail transport."
  type        = string
}

variable "ses_mail_from" {
  description = "Default From address for Ghost outbound mail."
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of running Ghost tasks."
  type        = number
  default     = 1
}

