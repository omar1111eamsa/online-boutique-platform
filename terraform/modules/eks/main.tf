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

# Default hop limit (1) only lets the host OS reach the EC2 instance
# metadata service, not pods (they're an extra network hop away) --
# breaks anything relying on IMDS auto-detection from inside a pod,
# like the AWS Load Balancer Controller's VPC auto-detect.
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
    }
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

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

resource "aws_eks_access_entry" "admin" {
  cluster_name = aws_eks_cluster.eks-cluster.name
  principal_arn = var.admin_principal_arn
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_ec2_tag" "cluster_sg" {
  resource_id = aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = var.karpenter_node_role_arn
  type          = "EC2_LINUX"
}