variable "rds_name" {
  description = "RDS Name"
  type        = string
}

variable "rds_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = number
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "from_port" {
  description = "Ingress From Port"
  type        = number
}

variable "to_port" {
  description = "Ingress To Port"
  type        = number
}

variable "db_parameters" {
  description = "DB Parameters"
  type        = list(any)
  default = [
    {
      apply_method = ""
      name         = ""
      value        = ""
    }
  ]
}

variable "db_username" {
  description = "Database username"
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  default     = "blockscout"
}

# Backup settings
variable "backup_retention_period" {
  description = "RDS automated backup retention period in days (1-35). If null, provider default is used."
  type        = number
  default     = null
}

variable "preferred_backup_window" {
  description = "Daily time range for taking automated backups, in UTC, format HH:MM-HH:MM (e.g., 03:00-04:00). If null, AWS chooses the window."
  type        = string
  default     = null

  validation {
    condition     = var.preferred_backup_window == null || can(regex("^([01]\\d|2[0-3]):[0-5]\\d-([01]\\d|2[0-3]):[0-5]\\d$", var.preferred_backup_window))
    error_message = "preferred_backup_window must be in format HH:MM-HH:MM (UTC), e.g., 03:00-04:00."
  }
}
