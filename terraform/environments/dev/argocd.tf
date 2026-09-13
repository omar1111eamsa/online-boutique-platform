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

  # Serve plain HTTP so the ALB terminates TLS in front of it,
  # and expose the UI via an ALB Ingress at argocd.myser.serghini.me
  values = [
    yamlencode({
      server = {
        insecure = true
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          hostname         = "argocd.myser.serghini.me"
          annotations = {
            "alb.ingress.kubernetes.io/certificate-arn"  = data.aws_acm_certificate.wildcard.arn
            "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "external-dns.alpha.kubernetes.io/hostname"  = "argocd.myser.serghini.me"
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}