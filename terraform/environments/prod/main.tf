# Prod environment — intentionally minimal.
#
# Not instantiated here (dev-only for this demo):
#   - module.ecr           (shared ECR repos live in dev)
#   - dns-tls.tf           (would use boutique.myser.serghini.me in prod)
#   - github-oidc.tf       (account-global OIDC provider, defined in dev)
#   - karpenter-iam.tf
#   - lb-controller-*.tf
#
# To enable: copy the relevant files from environments/dev/ and adjust
# cluster_name / domain_name / role names accordingly.

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name
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
  admin_principal_arn     = var.admin_principal_arn
  karpenter_node_role_arn = module.iam.node_role_arn
}
