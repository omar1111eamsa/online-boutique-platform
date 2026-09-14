# Architecture

## Overview

```mermaid
flowchart TB
    subgraph GitHub
        repo[online-boutique-platform repo]
        ci[GitHub Actions CI]
    end

    subgraph AWS["AWS (eu-west-1)"]
        subgraph dns_state["terraform/dns (permanent state)"]
            r53[Route53 zone: myser.serghini.me]
            acm[ACM wildcard cert]
        end

        ecr[ECR: per-service repos, IMMUTABLE tags]

        subgraph vpc["VPC"]
            subgraph eks["EKS cluster (boutique-dev)"]
                mng[Managed node group\n(runs Karpenter itself)]
                karp_nodes[Karpenter-provisioned nodes\n(app workloads)]
                lbc[AWS LB Controller]
                eso[External Secrets Operator]
                extdns[external-dns]
                argocd[ArgoCD]
                apps[online-boutique app pods]
                mon[kube-prometheus-stack]
            end
            alb[ALBs, created by LB Controller\nfrom Ingress objects]
        end
    end

    repo -- push to main --> ci
    ci -- OIDC AssumeRole, no static creds --> ecr
    ci -- docker push :sha --> ecr
    repo -- watched by --> argocd
    argocd -- syncs Helm chart --> apps
    apps -- images pulled from --> ecr
    lbc -- creates --> alb
    extdns -- writes records into --> r53
    alb -- TLS from --> acm
    karp_nodes -. scaled by .-> apps
```

## Components

| Component | Managed by | Purpose |
|---|---|---|
| VPC, subnets, NAT | Terraform (`modules/vpc`) | Network |
| EKS cluster + managed node group | Terraform (`modules/eks`) | Control plane + the one node group Karpenter itself runs on |
| Karpenter | Terraform (IAM/SA) + Helm | Provisions/terminates app-workload nodes on demand |
| ECR (per service, `IMMUTABLE`) | Terraform (`modules/ecr`) | Image storage; tags are commit SHAs only, never `:latest` |
| IAM (Karpenter, LB Controller, ESO, external-dns, GitHub OIDC) | Terraform | Least-privilege roles, scoped with `Condition` blocks where AWS allows it |
| Route53 zone + ACM cert | Terraform, **separate permanent state** (`terraform/dns`) | Decoupled so `destroy`/`apply` of the app environment never touches DNS delegation |
| AWS Load Balancer Controller | Helm (via ArgoCD or Terraform helm_release) | Turns k8s Ingress objects into ALBs |
| external-dns | Helm | Writes Route53 records for Ingress hostnames automatically |
| External Secrets Operator | Helm | Syncs AWS Secrets Manager values into k8s Secrets |
| ArgoCD | Terraform (`helm_release`) | GitOps: watches this repo, syncs the Helm chart for the app |
| online-boutique app + HPA | ArgoCD-managed Helm chart (`helm/online-boutique`) | The actual workload; each service has its own HPA (CPU+memory, 60% target) |
| kube-prometheus-stack | Helm (via ArgoCD) | Metrics/monitoring |
| GitHub Actions CI | `.github/workflows/ci.yml` | Trivy scan (report-only for now) -> build -> push to ECR via OIDC, main branch only |

## Ownership split: Terraform vs. ArgoCD

- **Terraform**: anything that provisions AWS resources outside the cluster
  (VPC, IAM, ECR, EKS control plane, Route53/ACM) plus the handful of
  cluster-bootstrap pieces that other things depend on (ArgoCD itself,
  Karpenter's IAM/service account).
- **ArgoCD (GitOps)**: the actual application — Deployments, Services,
  Ingress, HPAs — defined in `helm/online-boutique` and synced from this
  repo. Changing a hostname or scaling policy is a git push, not a
  `terraform apply`.
- Ingress/LoadBalancer-Service objects created by ArgoCD-managed charts
  still create real AWS resources (ALBs, security groups) that Terraform
  doesn't track. See `docs/DR-RUNBOOK.md` ("`terraform destroy` hangs on
  `aws_vpc`") for why that's handled with an automatic pre-destroy cleanup
  step instead of moving Ingress ownership into Terraform.

## CI/CD flow

1. Push to `main`.
2. CI runs Trivy (filesystem + image scans, currently report-only:
   `exit-code: 0` — gating is deferred until app-level CVEs are addressed).
3. CI builds each changed service, tags with `${{ github.sha }}` only.
4. CI assumes an IAM role via GitHub OIDC (no long-lived AWS credentials in
   CI) and pushes the image to ECR.
5. `helm/online-boutique/values.yaml` is bumped **manually** with the new
   SHA per service, then committed.
6. ArgoCD detects the git change and syncs the new image into the cluster.

Manual step 5 is deliberate for this single-operator project — see
`docs/DR-RUNBOOK.md` design decisions.

## Autoscaling

- **Pod-level**: HPA per service, CPU+memory at 60%/80% targets, scale-down
  by 50% of excess replicas every 60s (faster recovery from load-test
  spikes than a fixed pod-count step).
- **Node-level**: Karpenter provisions nodes for pods the managed node
  group can't fit; `topologySpreadConstraints` (soft, `ScheduleAnyway`)
  spread each service's replicas across nodes so a single node loss
  doesn't take out an entire service.
