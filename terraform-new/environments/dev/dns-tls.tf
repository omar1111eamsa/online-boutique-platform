resource "aws_acm_certificate" "boutique" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
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

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "boutique" {
  certificate_arn         = aws_acm_certificate.boutique.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

data "aws_lb" "frontend_alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
  }

  depends_on = [aws_acm_certificate_validation.boutique]
}

resource "aws_route53_record" "boutique" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.frontend_alb.dns
    zone_id                = data.aws_lb.frontend_alb.zon
    evaluate_target_health = true
  }
}