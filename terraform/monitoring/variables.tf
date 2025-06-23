variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "monitoring_stack_name" {
  description = "Name of the monitoring stack (used for labeling resources)"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID for persistent storage"
  type        = string
}

variable "enable_monitoring_persistence" {
  description = "Enable persistent storage for monitoring stack using static provisioning"
  type        = bool
  default     = false
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus data"
  type        = string
  default     = "20Gi"
}

variable "grafana_storage_size" {
  description = "Storage size for Grafana data"
  type        = string
  default     = "10Gi"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
} 