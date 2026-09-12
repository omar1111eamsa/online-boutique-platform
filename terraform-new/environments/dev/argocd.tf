resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # Register the private GitHub repo so Argo CD can clone it (no manual `argocd repo add`).
  set {
    name  = "configs.repositories.online-boutique.url"
    value = "https://github.com/omar1111eamsa/online-boutique-platform.git"
  }
  set {
    name  = "configs.repositories.online-boutique.username"
    value = "omar1111eamsa"
  }
  set_sensitive {
    name  = "configs.repositories.online-boutique.password"
    value = var.github_token
  }

  # Serve plain HTTP so the ALB terminates TLS in front of it
  set {
    name  = "server.insecure"
    value = "true"
  }

  depends_on = [module.eks]
}