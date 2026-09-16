resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }

  # Ensures this is destroyed before the access entry that lets Terraform
  # reach the cluster's API at all -- otherwise destroy order between two
  # resources with no direct dependency is arbitrary, and losing cluster
  # access mid-destroy leaves every remaining kubernetes_* resource stuck.
  depends_on = [module.eks]
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }

  depends_on = [module.eks]
}
