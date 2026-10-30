# Architecture

## Tenants: one per blast radius, on any cloud

A *tenant* is the unit of isolation a cloud offers: an AWS account, a GCP
project, a Hetzner project, a GitHub organization. `root.hcl` holds one map
entry per tenant with its cloud, id and where its state lives.

| Tenant (`<stage>/<leader>`) | Cloud | Holds | Why separate |
| --- | --- | --- | --- |
| shared/organization | AWS | Organizations, SCPs, Identity Center, budgets | the root of trust; almost never changes |
| shared/network | AWS | VPCs, Transit Gateways, VPN connector, flow logs | shared by workload accounts via RAM; no workload can delete a subnet |
| shared/security | AWS | Security Hub, audit logs, provider secrets | read by many, written by few |
| shared/deployment | AWS | registry, CI roles, build cache | the only tenant CI logs into directly; images are pulled cross-account |
| nonprod/uk, nonprod/us | AWS | EKS, RDS, Redis, queues | per-region nonprod, each can be rebuilt alone |
| prod/uk | AWS | the same layers as nonprod | prod differs by inputs, not by code |
| nonprod/gcp-eu | GCP | GKE Autopilot, Secret Manager | a second cloud with the same instance convention and GitOps bootstrap |
| nonprod/hetzner-eu | Hetzner | k3s, Cloudflare DNS | a provider with no state service; state in the organization bucket |
| shared/github | GitHub | org members, teams, repo, branch protection | infrastructure that is not a cloud at all |

Every tenant has its own state location. A mistake in one tenant's state
cannot touch another's.

## Regions: discovered, never listed

Nothing in the repository enumerates regions. Each thing that is per region
is one file in a conventional place, and everything else finds it:

| Who adds a region | Adds | Discovered by |
| --- | --- | --- |
| an app team | `apps/<app>/.platform/values-<stage>-<region>.yaml` | that cluster's ApplicationSet (`apps/*/.platform/values-<stage>-<region>.yaml`) |
| the platform team | `<layer>/environments/<stage>/<leader>/<region>/terragrunt.hcl` per layer | `root.hcl` (backend, identity from the path) and the inventory generator (`digger.yml`, dependency order) |
| the platform team | `platform-config/environments/<stage>-<region>.yaml` | the ArgoCD root app of that cluster, which renders the ApplicationSets from it |

The AWS network layer is instantiated once per region with non-overlapping
CIDRs and a Transit Gateway peering between them, declared as an
instance-level dependency so the accepter applies after the requester.

Adding a cloud is one `envs` entry in `root.hcl`, one cluster layer, and an
auth step in the stage workflow. No shared file beyond those is edited.

## Layers

```
foundations/   organization, network, iam-github, dns, security, sops, github-org
deployment/    registry, ci agents
workloads/     eks, gke, hetzner-k3s, argocd, rds, redis, messaging, s3, observability
```

A layer is one Terraform root. An *instance* of a layer is one directory with
one `terragrunt.hcl` holding only `inputs`. One instance = one state file =
one project in CI. A layer is cloud-specific by nature (eks vs gke); the
convention around it is not.

## Ownership

| Owns | What |
| --- | --- |
| Terraform | cloud resources, IAM, the ArgoCD install and root apps |
| The CD tool (Buildkite or GitHub Actions) | image builds and the prod promotion commit |
| ArgoCD | everything running in a cluster |
| The registry (`infra/access/`) | who can reach what |

No component crosses into another's area. ArgoCD never runs Terraform;
Terraform never deploys an app; CI never writes to a cluster.
