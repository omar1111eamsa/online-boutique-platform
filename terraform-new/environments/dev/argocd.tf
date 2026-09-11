resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "argocd_root_app" {
  manifest   = yamldecode(file("${path.module}/../../../gitops/root.yaml"))
  depends_on = [helm_release.argocd]
}