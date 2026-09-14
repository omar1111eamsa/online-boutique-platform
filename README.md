# Online Boutique Platform

Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)
(11 microservices, gRPC + HTTP, polyglot) deployed on real production-style
infrastructure: AWS EKS, Karpenter, GitOps via ArgoCD, least-privilege IAM,
and CI/CD with OIDC (no static AWS credentials anywhere).

Most public deployments of this demo stop at `kubectl apply` on a single
node pool. This one is built to survive the things that actually break in
production: a node dying, a destroy/apply cycle, an operator's IP changing,
over-broad IAM. Full details in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## What's different here

- **Node-level autoscaling with Karpenter**, IAM scoped per-action
  (`Condition` on resource tags where AWS supports it, not a blanket `*`).
- **GitOps with ArgoCD** — the app is deployed by pushing to `main`, not by
  running Helm by hand.
- **CI authenticates via GitHub OIDC**, restricted to `main`, zero long-lived
  AWS keys in GitHub secrets.
- **Immutable ECR tags** — every image is addressed by commit SHA;
  `:latest` doesn't exist in this pipeline, so a stale-image bug can't
  silently redeploy the wrong code.
- **HPA + Karpenter load-tested for real**, not just configured: tuned under
  an actual Locust run driving traffic through the frontend, watching pods
  and nodes scale live and fixing what broke along the way.
- **Pod topology spread** across nodes, so one node loss degrades a service
  instead of taking it fully down.
- **DNS/TLS state is permanently decoupled** from the app environment, so
  tearing the cluster down and rebuilding it never requires re-delegating
  nameservers.

## Real problems this hit, and how they were fixed

Everything below actually happened while operating this stack — not
hypothetical failure modes. Full runbook: [`docs/DR-RUNBOOK.md`](docs/DR-RUNBOOK.md).

| Problem | Root cause | Fix |
|---|---|---|
| `terraform apply` intermittently failed with `Kubernetes cluster unreachable` right after an IP-allowlist change | `public_access_cidrs` updates are asynchronous on AWS's side; applying it in the same run as anything hitting the k8s API races that propagation | Two-step apply: update the cluster resource alone, confirm `kubectl get nodes`, then apply everything else |
| `terraform destroy` hung 20+ minutes on the VPC, then failed with `DependencyViolation` | The AWS Load Balancer Controller creates security groups directly via the AWS API for every Ingress/LB Service — Terraform never tracks them, so they outlive the cluster | A destroy-time provisioner now deletes every Ingress/LB Service before the cluster dies, automatically, on every `terraform destroy` |
| `kubectl delete node` returned success but the node object never disappeared | A `karpenter.sh/termination` finalizer with no controller left to clear it | Diagnosed with `--v=6` raw HTTP tracing, then force-cleared the finalizer once the underlying instance was confirmed gone |
| Karpenter's IAM policy was one broad statement with `Resource: "*"` | Several EC2 actions genuinely can't be ARN-scoped (an AWS limitation, not laziness) | Split into read-only / create / modify-existing statements, and added `Condition` blocks on `aws:RequestTag`/`aws:ResourceTag` so create and terminate actions are restricted to resources tagged for this cluster |
| GitHub Actions could assume the deploy role from any branch or PR | OIDC trust policy used a wildcard `sub` claim | Restricted `sub` to `repo:<org>/<repo>:ref:refs/heads/main` |
| A floating `:latest` tag meant the actually-running image version was never verifiable | ECR was mutable, CI re-pushed `:latest` every build | ECR flipped to `IMMUTABLE`, CI pushes only the commit SHA, deploys reference that SHA explicitly |

## Docs

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — full component breakdown, diagram, CI/CD flow, autoscaling design
- [`docs/DR-RUNBOOK.md`](docs/DR-RUNBOOK.md) — rebuild-from-zero steps and every known failure mode with its fix
