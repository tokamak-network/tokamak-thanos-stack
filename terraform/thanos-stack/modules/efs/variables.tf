variable "efs_name" {
  description = "EFS Name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

# AWS Backup configuration for EFS - Always enabled for production-ready backup protection
variable "backup_schedule_cron" {
  description = "Cron expression for backup schedule (e.g., cron(0 3 * * ? *) for daily 03:00 UTC)"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "backup_delete_after_days" {
  description = "Number of days after which to delete the recovery point"
  type        = number
  default     = 35
}
