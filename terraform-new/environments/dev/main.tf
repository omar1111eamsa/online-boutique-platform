module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = var.vpc_cidr
  cluster_name = var.cluster_name
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "iam" {
  source = "../../modules/iam"

  cluster_name = var.cluster_name
}

module "eks" {
  source = "../../modules/eks"

  cluster_name            = var.cluster_name
  cluster_version         = var.cluster_version
  cluster_role_arn        = module.iam.cluster_role_arn
  node_role_arn           = module.iam.node_role_arn
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_instance_types     = var.node_instance_types
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  admin_principal_arn     = data.aws_caller_identity.current.arn
  karpenter_node_role_arn = module.iam.node_role_arn
}

module "ecr" {
  source = "../../modules/ecr"

  services             = var.services
  image_tag_mutability = "MUTABLE"
}