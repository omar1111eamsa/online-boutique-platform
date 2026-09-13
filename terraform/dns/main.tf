# Permanent Route53 hosted zone for myser.serghini.me.
#
# This lives in its own Terraform state, separate from the dev/staging/prod
# environments, specifically so it survives their destroy/apply cycles.
# Destroying and recreating a hosted zone assigns brand-new NS servers,
# which would require re-delegating myser.serghini.me at the domain
# registrar every single time — something we can't always do on demand.
#
# Environments consume this zone read-only via `data "aws_route53_zone"`
# (see environments/dev/dns-tls.tf) instead of creating it themselves.
resource "aws_route53_zone" "myser" {
  name = "myser.serghini.me"

  lifecycle {
    prevent_destroy = true
  }
}

# ACM certificates live here too, for the same reason as the zone: a
# hardcoded certificate-arn annotation (e.g. gitops/kube-prometheus-stack.yaml's
# Grafana Ingress) goes stale every time the dev environment's own
# aws_acm_certificate is destroyed and recreated with a new ARN. Keeping
# the certs in this permanent state means that ARN never changes, so
# hardcoding it in a static, git-committed manifest is no longer a bug.
#
# Environments consume these read-only via `data "aws_acm_certificate"`
# (see environments/dev/dns-tls.tf) instead of creating them themselves.
resource "aws_acm_certificate" "boutique" {
  domain_name       = "boutique.myser.serghini.me"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.boutique.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.myser.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "boutique" {
  certificate_arn         = aws_acm_certificate.boutique.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Wildcard cert covering grafana/argocd/prometheus/etc subdomains
resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.myser.serghini.me"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
  }
}

resource "aws_route53_record" "wildcard_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.myser.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard_cert_validation : record.fqdn]
}
