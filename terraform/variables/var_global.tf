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

variable "stack_chain_id" {
  description = "Chain id"
  type        = string
}

variable "stack_l1_beacon_url" {
  description = "L1 Beacon URL"
  type        = string
}
