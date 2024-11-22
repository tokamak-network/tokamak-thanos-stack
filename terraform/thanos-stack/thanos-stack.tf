data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket_name
    key    = "tokamak-thanos-stack/terraform/init/vpc/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "secretsmanager" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket_name
    key    = "tokamak-thanos-stack/terraform/init/secretsmanager/terraform.tfstate"
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

module "k8s" {
  source = "./modules/kubernetes"

  network_name                       = var.thanos_stack_name
  profile                            = "default"
  region                             = var.aws_region
  vpc_id                             = data.terraform_remote_state.vpc.outputs.vpc_id
  cluster_name                       = module.eks.cluster_name
  fargate_profiles                   = module.eks.fargate_profiles
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  aws_acm_certificate_validation     = module.acm.aws_acm_certificate_validation
  aws_secretsmanager_id              = data.terraform_remote_state.secretsmanager.outputs.aws_secretsmanager_id
  external_secret_namespace          = var.thanos_stack_name
}
