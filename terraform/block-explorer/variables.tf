variable "thanos_stack_name" {
  description = "Thanos stack name"
  type        = string
}


variable "aws_region" {
  description = "AWS region"
  default     = "ap-northeast-2"
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
