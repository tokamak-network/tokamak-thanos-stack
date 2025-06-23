terraform {
  required_version = ">= 1.5.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.17.0, < 6.0.0"
    }
  }
}

# 🔹 Fetch VPC Information
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# 🔹 Fetch Private Subnets (for RDS)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# -----------------------------
# RDS Instance (PostgreSQL)
# -----------------------------
module "rds" {
  source = "./modules/rds"

  vpc_id             = var.vpc_id
  private_subnet_ids = data.aws_subnets.private.ids

  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name
  from_port = 5432
  to_port   = 5432
  rds_allocated_storage = 50

  rds_name = "${var.thanos_stack_name}-rds"

  db_parameters = [
    {
      name         = "log_connections"
      value        = "1"
      apply_method = "pending-reboot"
    }
  ]
}
