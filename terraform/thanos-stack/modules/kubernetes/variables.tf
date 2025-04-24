variable "network_name" {
  description = "Network Name"
  type        = string
}

variable "profile" {
  description = "AWS CLI Profile"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "vpc_id" {
  description = "VPC"
  type        = any
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "fargate_profiles" {
  description = "Cluster Fargate Profile"
  type        = any
}

variable "cluster_endpoint" {
  description = "Cluster Endpoint"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Cluster Certificate Authority Data"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "Cluster OIDC Issuer URL"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  type        = string
}

variable "aws_secretsmanager_id" {
  description = "AWS_Secretmanager_ID"
  type        = string
}

variable "external_secret_namespace" {
  description = "External_Secret_Namespace"
  type        = string
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

variable "stack_efs_id" {
  description = "EFS id"
  type        = string
}

variable "stack_genesis_file_url" {
  description = "Genesis file URL"
  type        = string
}

variable "stack_prestate_file_url" {
  description = "Prestate file URL"
  type        = string
}

variable "stack_rollup_file_url" {
  description = "Rollup file URL"
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
  description = "Max channel duration"
  type        = string
}
