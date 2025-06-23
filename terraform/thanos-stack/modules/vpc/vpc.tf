module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 5.17.0, < 6.0.0"

  name = var.vpc_name
  azs  = var.azs
  cidr = var.vpc_cidr

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnets = [
    for index in range(length(var.azs)) :
    cidrsubnet(var.vpc_cidr, 4, index)
  ]

  public_subnets = [
    for index in range(length(var.azs)) :
    cidrsubnet(var.vpc_cidr, 4, index + length(var.azs))
  ]

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.vpc_name}" = "shared"
    "kubernetes.io/role/internal-elb"       = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.vpc_name}" = "shared"
    "kubernetes.io/role/elb"                = "1"
  }
}
