variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "domain_name" {
  description = "Environment domain for Ghost URL."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID used for ACM DNS validation."
  type        = string
}

variable "db_password" {
  description = "MySQL password for Ghost database."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs configuration."
  type        = string
}

variable "ghost_image" {
  description = "Container image for Ghost."
  type        = string
  default     = "ghost:5-alpine"
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

