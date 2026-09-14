# Disaster Recovery Runbook

Procedures for rebuilding this environment from zero, and fixes for the
specific failures that have actually happened while operating it.

## Full rebuild from zero

```bash
cd terraform/environments/dev
terraform init
terraform destroy   # pre_destroy_cleanup runs automatically, see below
terraform apply -target=module.eks.aws_eks_cluster.eks-cluster
kubectl get nodes   # confirm cluster is reachable before continuing
terraform apply
```

Do NOT run a single `terraform apply` for everything at once on a fresh
cluster. See "EKS endpoint access race" below for why.

`terraform/dns/` is a separate, permanent state and must never be destroyed —
it owns the Route53 zone and ACM certs that the rest of the stack depends on
via `data` sources, not resource ownership.

## Known failure modes

### 1. EKS public API endpoint rejects you after your IP changes

**Symptom:** `kubectl` / `terraform apply` hang or fail with connection
timeouts to the cluster API.

**Cause:** the endpoint is public but locked to `public_access_cidrs`. Your
home/hotspot IP is not static.

**Fix:**
```bash
curl -s ifconfig.me   # get current public IP
# update public_access_cidrs in terraform.tfvars or the module call to include it
terraform apply -target=module.eks.aws_eks_cluster.eks-cluster
```
Then verify with `kubectl get nodes` before doing anything else.

### 2. EKS endpoint access update races other resources ("Kubernetes cluster unreachable")

**Symptom:** `terraform apply` fails with
`dial tcp ...: i/o timeout` on `kubernetes_namespace`, `kubernetes_service_account`,
etc., right after changing `public_access_cidrs`.

**Cause:** `public_access_cidrs` changes are asynchronous on AWS's side
(`EndpointAccessUpdate`, ~1-2 min to propagate). Applying it in the same
`terraform apply` as anything that talks to the Kubernetes API races that
propagation.

**Fix:** two-step apply, always:
```bash
terraform apply -target=module.eks.aws_eks_cluster.eks-cluster
kubectl get nodes   # wait until this works
terraform apply
```

### 3. `terraform destroy` hangs on `aws_vpc` with `DependencyViolation`

**Symptom:** `Still destroying...` on `module.vpc.aws_vpc.main` for 10+
minutes, then `DependencyViolation: has dependencies and cannot be deleted`.

**Cause:** the AWS Load Balancer Controller creates security groups (and
ALBs/NLBs) directly via the AWS API for every Ingress / `Service type:
LoadBalancer` — Terraform never tracks these. If the cluster dies before
the controller processes the object's deletion, the security groups orphan
and block VPC deletion.

**Fix (automatic, as of this runbook):** `pre-destroy-cleanup.tf` defines a
`null_resource` with a destroy-time provisioner that deletes all
Ingress/LoadBalancer-Service objects and waits 45s for the controller to
clean up, before the cluster/VPC are destroyed. This runs automatically on
every `terraform destroy` — no manual step needed.

**Caveat:** this only works if the EKS API is still reachable when destroy
starts. If you're mid-failure-mode #1 (IP not allowlisted) when you run
destroy, the cleanup step silently no-ops. Fix #1 first, confirm
`kubectl get nodes` works, then destroy.

**Manual fallback**, if orphaned SGs block a VPC delete anyway:
```bash
VPC_ID=<id from the error>
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]' --output table
aws ec2 delete-security-group --group-id <each sg-id>
terraform destroy   # retry
```

### 4. Stale Terraform state lock

**Symptom:** `Error acquiring the state lock ... PreconditionFailed`.

**Fix:** confirm nothing else is actually running (`pgrep -af terraform`),
then:
```bash
terraform force-unlock -force <LOCK_ID>   # ID is printed in the error
```

### 5. Kubernetes node stuck deleting (finalizer never clears)

**Symptom:** `kubectl delete node <name>` returns success but the node
object persists indefinitely.

**Cause:** a finalizer (e.g. `karpenter.sh/termination`) never gets cleared
because the controller that owns it (e.g. the NodeClaim) is already gone.

**Diagnose:**
```bash
kubectl get node <name> -o jsonpath='{.metadata.finalizers}'
kubectl delete node <name> --v=6   # confirms the DELETE actually returns 200
```

**Fix**, only after confirming the underlying instance/resource is actually
gone:
```bash
kubectl patch node <name> --type=merge -p '{"metadata":{"finalizers":[]}}'
```

### 6. New managed-node-group instance never registers

**Symptom:** ASG shows `InService`/healthy, but the instance never appears
in `kubectl get nodes` and never registers with SSM, for an extended period
(seen: 1+ hour), despite AMI/NAT/health checks all looking fine.

**Cause:** not conclusively root-caused. Treated as a rare bad launch.

**Fix:** terminate the stuck instance(s) and let the ASG launch a
replacement:
```bash
aws ec2 terminate-instances --instance-ids <id>
```

## Design decisions (why things are the way they are)

- **EKS API endpoint is public with an IP allowlist**, not private-only
  behind a bastion. Chosen for solo-dev simplicity; the tradeoff is
  failure mode #1 above every time the operator's IP changes.
- **Terraform owns infra/IAM/networking; ArgoCD owns app manifests**
  (Deployments, Services, Ingress) via GitOps. Considered moving
  Ingress/LoadBalancer-Service ownership into Terraform after failure mode
  #3, but the `pre_destroy_cleanup` null_resource fixes the actual risk
  without giving up GitOps for app-level changes.
- **ECR is `IMMUTABLE`**; CI pushes only a commit-SHA tag, never `:latest`.
  `values.yaml` image tags are bumped manually after a CI build, not
  automated via a CI-writes-back-to-git step — deliberately kept simple for
  a single-operator setup.
