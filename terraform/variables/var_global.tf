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
