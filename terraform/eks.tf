data "http" "my_IP" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_public_ip_cidr = "${chomp(data.http.my_IP.response_body)}/32"
}

resource "aws_eks_cluster" "eks-cluster" {
  name = "eks-cluster"
  access_config {
    authentication_mode = "API"
  }

  role_arn = module.iam.cluster_role_arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = module.vpc.private_subnet_ids
    public_access_cidrs     = [local.my_public_ip_cidr]
  }

  depends_on = [module.iam]
  version    = "1.33"
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "main-node-group"
  node_role_arn   = module.iam.node_role_arn
  subnet_ids      = module.vpc.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  depends_on = [module.iam]

  instance_types = ["c7i-flex.large"]
}
