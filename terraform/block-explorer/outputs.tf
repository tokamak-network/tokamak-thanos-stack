output "rds_connection_url" {
  value = "postgres://${var.db_username}:${var.db_password}@${module.rds.rds_endpoint}"
  sensitive = true
}

output "rds_endpoint" {
  value = module.rds.rds_endpoint
}

output "rds_address" {
  value = module.rds.rds_address
}

output "rds_port" {
  value = module.rds.rds_port
}
