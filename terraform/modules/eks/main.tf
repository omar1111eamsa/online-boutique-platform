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

# Default VPC CNI hands out one secondary IP per pod, capping small instance
# types at ~29 pods regardless of free CPU/memory -- under an HPA scale-out
# burst, nodes hit that IP ceiling and new pods fail with
# "failed to assign an IP address to container" long before compute limits.
# Prefix delegation hands out a /28 (16 IPs) per ENI instead, raising that
# ceiling to 100+ pods on the same instance types.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  addon_name    = "vpc-cni"
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
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

  # Without a reservation, pods can consume 100% of the node's CPU/memory,
  # starving kubelet itself -- it misses its heartbeat to the API server and
  # the node goes NotReady even though the instance is otherwise healthy.
  # nodeadm merges this partial NodeConfig into its own auto-generated
  # cluster-join config, so only the kubelet overrides need to be listed here.
  user_data = base64encode(<<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          systemReserved:
            cpu: "250m"
            memory: "500Mi"
          kubeReserved:
            cpu: "250m"
            memory: "500Mi"
          evictionHard:
            memory.available: "5%"
          # nodeadm's default max-pods calculation doesn't know prefix
          # delegation is on -- without this override it stays at the
          # pre-prefix-delegation ceiling (~29) no matter how many IPs
          # the CNI can actually hand out.
          maxPods: 110
  EOT
  )
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