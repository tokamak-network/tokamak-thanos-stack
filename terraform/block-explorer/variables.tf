variable "thanos_stack_name" {
  description = "Thanos stack name"
  type        = string
}


variable "aws_region" {
  description = "AWS region"
  default     = "ap-northeast-2"
  type        = string
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

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

# RDS backup options (consumed by modules/rds)
variable "backup_retention_period" {
  description = "RDS automated backup retention period in days (1-35). If null, provider default is used."
  type        = number
  default     = null
}

variable "preferred_backup_window" {
  description = "Daily time range for taking automated backups, in UTC, format HH:MM-HH:MM (e.g., 03:00-04:00). If null, AWS chooses the window."
  type        = string
  default     = null
}
