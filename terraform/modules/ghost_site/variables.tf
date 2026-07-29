variable "environment" {
  description = "Environment name for this Ghost site."
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name."
  type        = string
}

variable "subdomain" {
  description = "Subdomain to use for this Ghost site."
  type        = string
}

variable "db_password" {
  description = "MySQL password for Ghost database."
  type        = string
  sensitive   = true
}

variable "local_dev_ip" {
  description = "Optional public IPv4 address for local development access to MySQL (without /32)."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs configuration."
  type        = string
}

variable "ghost_image" {
  description = "Container image for Ghost."
  type        = string
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

