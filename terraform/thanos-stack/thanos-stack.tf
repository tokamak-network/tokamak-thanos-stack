module "secretsmanager" {
  source = "./modules/secretsmanager"

  secretsmanager_name = var.thanos_stack_name
  sequencer_key       = var.sequencer_key
  batcher_key         = var.batcher_key
  proposer_key        = var.proposer_key
  challenger_key      = var.challenger_key
}

module "vpc" {
  source = "./modules/vpc/"

  vpc_name = var.thanos_stack_name
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
}

module "chain_config" {
  source = "./modules/chain-config"

  thanos_stack_name  = var.thanos_stack_name
  genesis_file_path  = var.genesis_file_path
  rollup_file_path   = var.rollup_file_path
  prestate_file_path = var.prestate_file_path
  prestate_hash      = var.prestate_hash
}

module "eks" {
  source = "./modules/eks"

  region             = var.aws_region
  cluster_name       = var.thanos_stack_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  eks_cluster_admins = var.eks_cluster_admins
}

module "efs" {
  source = "./modules/efs"

  efs_name           = var.thanos_stack_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "k8s" {
  source = "./modules/kubernetes"

  network_name                       = var.thanos_stack_name
  profile                            = "default"
  region                             = var.aws_region
  vpc_id                             = module.vpc.vpc_id
  cluster_name                       = module.eks.cluster_name
  fargate_profiles                   = module.eks.fargate_profiles
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  aws_secretsmanager_id              = module.secretsmanager.aws_secretsmanager_id
  external_secret_namespace          = var.thanos_stack_name
  stack_deployments_path             = var.stack_deployments_path
  stack_l1_rpc_url                   = var.stack_l1_rpc_url
  stack_l1_rpc_provider              = var.stack_l1_rpc_provider
  stack_l1_beacon_url                = var.stack_l1_beacon_url
  stack_efs_id                       = module.efs.efs_id
  stack_genesis_file_url             = module.chain_config.genesis_file_url
  stack_rollup_file_url              = module.chain_config.rollup_file_url
  stack_prestate_file_url            = module.chain_config.prestate_file_url
  stack_op_geth_image_tag            = var.stack_op_geth_image_tag
  stack_thanos_stack_image_tag       = var.stack_thanos_stack_image_tag
  stack_max_channel_duration         = var.stack_max_channel_duration
}
