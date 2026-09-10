module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnet_cidrs = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
  cluster_name         = "eks-cluster"
}

module "iam" {
  source = "./modules/iam"

  cluster_name = "eks-cluster"
}
