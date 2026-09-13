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
