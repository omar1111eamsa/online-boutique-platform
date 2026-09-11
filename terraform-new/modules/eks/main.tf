data "http" "my_IP" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_public_ip_cidr = "${chomp(data.http.my_IP.response_body)}/32"
}

resource "aws_eks_cluster" "eks-cluster" {
  name    = var.cluster_name
  version = var.cluster_version
  role_arn = var.cluster_role_arn

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = var.private_subnet_ids
    public_access_cidrs     = [local.my_public_ip_cidr]
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${var.cluster_name}-main"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = var.node_instance_types
}