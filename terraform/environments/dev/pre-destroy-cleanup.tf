# The AWS Load Balancer Controller creates security groups (and ALBs/NLBs) directly
# via the AWS API whenever a k8s Ingress or a Service of type LoadBalancer exists --
# Terraform never sees or tracks these. If the cluster is destroyed while those
# objects still exist, the controller never gets a chance to clean up, and the
# orphaned security groups block `aws_vpc` deletion (DependencyViolation).
#
# This resource does nothing on create. On `terraform destroy`, its provisioner
# runs BEFORE module.eks/helm_release.argocd are destroyed (Terraform destroys
# dependents before their dependencies), deleting every Ingress/LoadBalancer
# Service first so the controller can clean up its AWS-side resources while the
# cluster is still alive to run it.
resource "null_resource" "pre_destroy_cleanup" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }

  depends_on = [module.eks, helm_release.argocd]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || exit 0
      kubectl delete ingress --all -A --timeout=60s || true
      kubectl delete svc --all -A --field-selector spec.type=LoadBalancer --timeout=60s || true
      echo "Waiting for AWS Load Balancer Controller to remove ALBs/target groups/security groups..."
      sleep 45
    EOT
  }
}
