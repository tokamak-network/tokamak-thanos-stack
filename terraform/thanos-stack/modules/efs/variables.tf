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

# Optional AWS Backup plan configuration for EFS
variable "backup_enabled" {
  description = "Enable creating AWS Backup plan/selection for this EFS"
  type        = bool
  default     = false
}

variable "backup_vault_name" {
  description = "Name of the AWS Backup Vault to store backups. If empty, the default vault is used."
  type        = string
  default     = ""
}

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

variable "backup_resource_tags" {
  description = "Tags used to select EFS for backup selection (optional). If empty, will target this module EFS only."
  type        = map(string)
  default     = {}
}

variable "backup_iam_role_arn" {
  description = "IAM role ARN for AWS Backup to assume. If empty, uses the default AWSBackupDefaultServiceRole."
  type        = string
  default     = ""
}
