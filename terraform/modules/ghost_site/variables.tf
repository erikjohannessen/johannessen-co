variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "domain_name" {
  description = "Environment domain for Ghost URL."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Ghost."
  type        = string
}

variable "db_password" {
  description = "MySQL password for Ghost database."
  type        = string
  sensitive   = true
}

variable "ssh_allowed_ip" {
  description = "IP Address that is allowed to SSH into Ghost"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name to use for SSH access. Leave null to disable key-based SSH login."
  type        = string
  default     = null
}

