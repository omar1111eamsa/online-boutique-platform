module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = var.vpc_cidr
  cluster_name = var.cluster_name
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}