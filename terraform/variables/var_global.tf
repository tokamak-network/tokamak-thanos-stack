variable "thanos_stack_name" {
  description = "Thanos stack name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "chain_domain_name" {
  description = "Thanos stack chain domain name"
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
  description = "Thanos proposer private key"
  sensitive   = true
}
