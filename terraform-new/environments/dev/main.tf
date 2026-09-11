module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = var.vpc_cidr
  cluster_name = var.cluster_name
}