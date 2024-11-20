data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket_name
    key    = "tokamak-thanos-stack/terraform/init/vpc/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks" {
  source = "./modules/eks"

  region             = var.aws_region
  cluster_name       = var.thanos_stack_name
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  eks_cluster_admins = var.eks_cluster_admins
}

module "efs" {
  source = "./modules/efs"

  efs_name           = var.thanos_stack_name
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

module "acm" {
  source = "./modules/acm"

  parent_domain = var.chain_domain_name
  service_names = ["*"]
}


module "rds" {
  source = "./modules/rds"

  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  rds_name = "${var.thanos_stack_name}-rds"

  rds_allocated_storage = 500

  from_port = 5432
  to_port   = 5432

  db_parameters = [
    {
      name         = "log_connections"
      value        = "1"
      apply_method = "pending-reboot"
    }
  ]
}
