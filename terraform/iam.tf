resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = "arn:aws:iam::858093957996:user/terrafrom-aws"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = "arn:aws:iam::858093957996:user/terrafrom-aws"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
