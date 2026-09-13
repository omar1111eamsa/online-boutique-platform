# The hosted zone AND the ACM certificates are created and owned by
# terraform/dns/ (a separate, permanent state), NOT here -- so
# destroying/recreating this environment never changes the zone's NS
# servers, never requires re-delegating the domain at the registrar, and
# never changes a certificate's ARN (which several gitops/*.yaml files
# reference by hardcoded value in Ingress annotations). These are all
# read-only lookups.
data "aws_route53_zone" "myser" {
  name = "myser.serghini.me"
}

data "aws_acm_certificate" "boutique" {
  domain   = "boutique.myser.serghini.me"
  statuses = ["ISSUED"]
}

# Wildcard cert covering grafana/argocd/prometheus/etc subdomains
data "aws_acm_certificate" "wildcard" {
  domain   = "*.myser.serghini.me"
  statuses = ["ISSUED"]
}

# The `boutique.myser.serghini.me` A alias is created automatically by external-dns
# (watches the Ingress + ALB), so Terraform does not manage it here.
