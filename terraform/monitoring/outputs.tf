output "monitoring_storage_class_name" {
  description = "Name of the monitoring StorageClass"
  value       = var.enable_monitoring_persistence ? kubernetes_storage_class.monitoring_efs_sc[0].metadata[0].name : null
}

output "prometheus_pv_name" {
  description = "Name of the Prometheus PersistentVolume"
  value       = var.enable_monitoring_persistence ? kubernetes_persistent_volume.monitoring_prometheus[0].metadata[0].name : null
}

output "grafana_pv_name" {
  description = "Name of the Grafana PersistentVolume"
  value       = var.enable_monitoring_persistence ? kubernetes_persistent_volume.monitoring_grafana[0].metadata[0].name : null
}

output "monitoring_persistence_enabled" {
  description = "Whether monitoring persistence is enabled"
  value       = var.enable_monitoring_persistence
}

output "efs_file_system_id" {
  description = "EFS file system ID used for monitoring"
  value       = var.efs_file_system_id
} 