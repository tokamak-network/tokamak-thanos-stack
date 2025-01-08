output "efs_id" {
  value = module.efs.efs_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "aws_secretsmanager_id" {
  value = module.secretsmanager.aws_secretsmanager_id
}
