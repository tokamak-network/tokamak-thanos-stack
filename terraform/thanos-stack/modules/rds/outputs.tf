output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "rds_address" {
  value = aws_db_instance.default.address
}

output "rds_port" {
  value = aws_db_instance.default.port
}
