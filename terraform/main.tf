module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = "eks-cluster"
}

module "iam" {
  source = "./modules/iam"

  cluster_name = "eks-cluster"
}

module "eks" {
  source = "./modules/eks"

  cluster_name            = "eks-cluster"
  cluster_version         = "1.33"
  cluster_role_arn        = module.iam.cluster_role_arn
  node_role_arn           = module.iam.node_role_arn
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_instance_types     = ["c7i-flex.large"]
  node_desired_size       = 2
  node_min_size           = 2
  node_max_size           = 2
  admin_principal_arn     = "arn:aws:iam::858093957996:user/terrafrom-aws"
  karpenter_node_role_arn = aws_iam_role.karpenter_node.arn
}

module "ecr" {
  source = "./modules/ecr"

  services             = var.services
  image_tag_mutability = "MUTABLE"
}
