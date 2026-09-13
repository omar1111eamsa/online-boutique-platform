resource "local_file" "helm_values" {
  filename = "${path.module}/../../../helm/online-boutique/values-dev.yaml"
  content = templatefile("${path.module}/values-dev.tftpl", {
    aws_account_id  = data.aws_caller_identity.current.account_id
    aws_region      = var.region
    domain_name     = var.domain_name
    certificate_arn = data.aws_acm_certificate.boutique.arn
  })
}