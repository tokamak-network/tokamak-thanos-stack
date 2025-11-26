variable "thanos_stack_name" {
  description = "Thanos stack name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "backend_bucket_name" {
  description = "AWS backend bucket name"
  type        = string
}

variable "eks_cluster_admins" {
  description = "eks cluster administrators"
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type        = string
  default     = "192.168.0.0/16"
}

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = ["ap-northeast-2a"]
}

variable "sequencer_key" {
  description = "Thanos sequencer private key"
  sensitive   = true
}

variable "batcher_key" {
  description = "Thanos batcher private key"
  sensitive   = true
}

variable "proposer_key" {
  description = "Thanos proposer private key"
  sensitive   = true
}

variable "challenger_key" {
  description = "Thanos challenger private key"
  sensitive   = true
}

variable "genesis_file_path" {
  description = "Local path to the Genesis file for uploading"
}

variable "rollup_file_path" {
  description = "Local path to the Rollup file for uploading"
}

variable "prestate_file_path" {
  description = "Local path to the Rollup file for uploading"
}

variable "prestate_hash" {
  description = "Prestate hash"
}

variable "stack_deployments_path" {
  description = "deployments path"
  type        = string
}

variable "stack_l1_rpc_url" {
  description = "L1 RPC URL"
  type        = string
}

variable "stack_l1_rpc_provider" {
  description = "L1 RPC provider"
  type        = string
}

variable "stack_l1_beacon_url" {
  description = "L1 Beacon URL"
  type        = string
}

variable "stack_op_geth_image_tag" {
  description = "OP Geth image tag"
  type        = string
}

variable "stack_thanos_stack_image_tag" {
  description = "Thanos Stack image tag"
  type        = string
}

variable "stack_max_channel_duration" {
  description = "Max channel duration in seconds"
  type        = string
}

# EFS backup configuration - Always enabled for production-ready backup protection
variable "backup_schedule_cron" {
  description = "Cron expression for EFS backup schedule"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "backup_delete_after_days" {
  description = "Days after which EFS recovery points are deleted (0 = unlimited retention, recommended for blockchain)"
  type        = number
  default     = 0  # Changed to unlimited retention for blockchain safety
}

variable "txmgr_cell_proof_time" {
  description = "Transaction manager cell proof time (activation timestamp)"
  type        = string
}
