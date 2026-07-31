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

