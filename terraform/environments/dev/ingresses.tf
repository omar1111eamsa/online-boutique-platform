# Generates the kube-prometheus-stack Argo CD Application with the Grafana
# ingress values + wildcard cert ARN baked in (mirrors the values-dev.yaml pattern).
resource "local_file" "kube_prometheus_stack_app" {
  filename = "${path.module}/../../../gitops/kube-prometheus-stack.yaml"
  content = templatefile("${path.module}/kube-prometheus-stack.tftpl", {
    certificate_arn = data.aws_acm_certificate.wildcard.arn
  })
}
