# Kubernetes-managed AWS resources are NOT tracked in Terraform state:
#   - ALBs created by the AWS Load Balancer Controller for every Ingress
#     (frontend, ArgoCD, Grafana, ...)
#   - EC2 nodes provisioned by Karpenter's NodePool (only the managed node
#     group in module.eks is Terraform-tracked)
#
# `terraform destroy` doesn't know either of these exist, so it tries to
# delete the VPC subnets and internet gateway while their ENIs are still
# attached -- and hangs (or eventually fails with DependencyViolation).
#
# This resource runs ONLY on `terraform destroy`. `depends_on` forces
# Terraform to destroy it *before*:
#   - module.eks (and therefore before module.vpc, which module.eks itself
#     depends on) -- so the cluster/API are still reachable, and subnets
#     aren't touched concurrently with this cleanup
#   - module.vpc directly, for the same reason (module.eks depending on
#     module.eks alone does not also order module.vpc's own resources)
#   - the load-balancer-controller's own ServiceAccount/IAM role/policy
#     attachment -- otherwise Terraform can (and did, once) destroy the
#     controller's credentials mid-cleanup, crashing it with `Unauthorized`
#     before it finishes deleting the ALBs it owns
#
# Its destroy-time provisioner deletes every Ingress and LoadBalancer
# Service so the controller cleans up its own ALBs/ENIs, terminates any
# Karpenter-provisioned EC2 nodes directly (Karpenter's own controller has
# no such ordering protection, so we don't rely on it being alive), and
# polls AWS until both are actually gone -- so by the time Terraform
# reaches the subnets, nothing is attached to them anymore.
resource "terraform_data" "cleanup_load_balancers" {
  triggers_replace = {
    cluster_name = module.eks.cluster_name
    region       = var.region
  }

  depends_on = [
    module.eks,
    module.vpc,
    kubernetes_service_account.lb_controller,
    aws_iam_role.lb_controller,
    aws_iam_role_policy_attachment.lb_controller,
  ]

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      CLUSTER="${self.triggers_replace.cluster_name}"
      REGION="${self.triggers_replace.region}"

      # If the cluster/API is already gone there's nothing to clean up.
      aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" || exit 0

      echo "Terminating Karpenter-provisioned EC2 nodes for $CLUSTER..."
      IDS=$(aws ec2 describe-instances --region "$REGION" \
        --filters "Name=tag-key,Values=karpenter.sh/nodepool" \
                   "Name=tag:kubernetes.io/cluster/$CLUSTER,Values=owned" \
                   "Name=instance-state-name,Values=running,pending,stopping" \
        --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)
      if [ -n "$IDS" ]; then
        aws ec2 terminate-instances --region "$REGION" --instance-ids $IDS >/dev/null 2>&1 || true
        echo "  waiting for $IDS to terminate..."
        aws ec2 wait instance-terminated --region "$REGION" --instance-ids $IDS 2>/dev/null || true
      fi

      echo "Deleting all Ingresses and LoadBalancer Services to release ALBs..."
      kubectl delete ingress --all -A --timeout=60s --ignore-not-found=true || true
      kubectl delete svc -A --field-selector spec.type=LoadBalancer --timeout=60s --ignore-not-found=true || true

      echo "Waiting for this cluster's load balancers to be deleted..."
      for i in $(seq 1 30); do
        ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null || true)
        if [ -z "$ARNS" ]; then
          echo "no load balancers left in the region"
          break
        fi
        REMAINING=$(aws elbv2 describe-tags --region "$REGION" --resource-arns $ARNS --output json 2>/dev/null \
          | jq --arg c "$CLUSTER" '[.TagDescriptions[] | select(.Tags[] | select(.Key=="elbv2.k8s.aws/cluster" and .Value==$c))] | length')
        if [ "$REMAINING" -eq 0 ]; then
          echo "this cluster's load balancers are gone"
          break
        fi
        echo "  still waiting on $REMAINING load balancer(s) for $CLUSTER... ($i/30)"
        sleep 10
      done
    EOT
  }
}
