output "genesis_file_url" {
  description = "URL of the genesis file"
  value       = "https://${aws_s3_bucket.config_files.id}.s3.${aws_s3_bucket.config_files.region}.amazonaws.com/${aws_s3_object.provision_genesis_file.key}"
}

output "rollup_file_url" {
  description = "URL of the rollup file"
  value       = "https://${aws_s3_bucket.config_files.id}.s3.${aws_s3_bucket.config_files.region}.amazonaws.com/${aws_s3_object.provision_rollup_file.key}"
}
