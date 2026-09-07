resource "aws_ec2_tag" "cluster_sg" {
  resource_id = aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id
  key         = "kubernetes.io/cluster/eks-cluster"
  value       = "owned"
}