# Architecture

## Tenants: one per blast radius, on any cloud

A *tenant* is the unit of isolation a cloud offers: an AWS account, a GCP
project, a Hetzner project, a GitHub organization. Nothing shares state,
credentials or a network with a tenant it does not need to.

```mermaid
flowchart TB
  subgraph shared[shared tenants]
    ORG[organization<br/>SCPs · Identity Center · budgets]
    NET[network<br/>VPCs · Transit Gateway · VPN]
    SEC[security<br/>audit · Security Hub · provider secrets]
    DEP[deployment<br/>registry · CI identity · build cache]
  end
  subgraph workloads[workload tenants]
    NPUK[nonprod / uk<br/>eu-west-2]
    NPUS[nonprod / us<br/>us-east-1]
    PRUK[prod / uk<br/>eu-west-2]
    GCP[nonprod / gcp-eu<br/>europe-west1]
    HZ[nonprod / hetzner-eu<br/>nbg1]
  end
  GHO[shared / github<br/>org · teams · branch rules]
  NET -->|RAM-shared subnets| NPUK & NPUS & PRUK
  DEP -->|images pulled cross-account| NPUK & NPUS & PRUK & GCP
  DEP -->|CI role chain-assumes| NPUK & NPUS & PRUK & NET & SEC & ORG
  ORG -.->|SCPs| workloads
```

| Tenant (`<stage>/<leader>`) | Cloud | Holds | Why separate |
| --- | --- | --- | --- |
| shared/organization | AWS | Organizations, SCPs, Identity Center, budgets | the root of trust; almost never changes |
| shared/network | AWS | VPCs, Transit Gateways, VPN connector, flow logs | shared by workload accounts via RAM; no workload can delete a subnet |
| shared/security | AWS | Security Hub, audit logs, provider secrets | read by many, written by few |
| shared/deployment | AWS | registry, CI roles, build cache | the only tenant CI logs into directly |
| nonprod/uk, nonprod/us | AWS | EKS, RDS, Redis, queues | per-region nonprod, each can be rebuilt alone |
| prod/uk | AWS | the same layers as nonprod | prod differs by inputs, not by code |
| nonprod/gcp-eu | GCP | GKE Autopilot, Secret Manager | a second cloud with the same conventions |
| nonprod/hetzner-eu | Hetzner | k3s, Cloudflare DNS | a provider with no state service |
| shared/github | GitHub | members, teams, repo, branch protection | infrastructure that is not a cloud |

Every tenant has its own state location. A mistake in one tenant's state
cannot touch another's.

## Regions: discovered, never listed

Nothing in the repository enumerates regions. Each per-region thing is one
file in a conventional place, and everything else finds it.

```mermaid
flowchart LR
  subgraph app[app team adds]
    A["apps/api/.platform/<br/>values-nonprod-us-east-1.yaml"]
  end
  subgraph platform[platform team adds]
    E["platform-config/environments/<br/>nonprod-us-east-1.yaml"]
    T["eks/environments/<br/>nonprod/us/us-east-1/terragrunt.hcl"]
  end
  T -->|path → backend, identity| R[root.hcl]
  T -->|scan + layer.yaml| G[generated digger.yml<br/>stages by dependency]
  E -->|renders| AS[ApplicationSet<br/>apps-nonprod-us-east-1]
  AS -->|discovers| A
```

| Who adds a region | Adds | Discovered by |
| --- | --- | --- |
| an app team | `apps/<app>/.platform/values-<stage>-<region>.yaml` | that cluster's ApplicationSet |
| the platform team | one `terragrunt.hcl` per layer the cluster needs | `root.hcl` and the inventory generator |
| the platform team | `platform-config/environments/<stage>-<region>.yaml` | the cluster's ArgoCD root app |

Two AWS regions share nothing but a Transit Gateway peering, declared as an
instance-level dependency so the accepter applies after the requester.

```mermaid
flowchart LR
  subgraph euw2[eu-west-2]
    V1[nonproduction VPC] --- T1[TGW hub]
    V2[production VPC] --- T1
  end
  subgraph use1[us-east-1]
    V3[nonproduction VPC] --- T2[TGW hub]
  end
  T1 <-->|peering| T2
```

## Layers

A layer is one Terraform root. An *instance* is one directory with one
`terragrunt.hcl` holding only inputs. One instance = one state file = one
CI project.

```mermaid
flowchart BT
  subgraph foundations
    F1[organization]
    F2[network]
    F3[iam-github]
    F4[sops]
    F5[github-org]
  end
  subgraph deployment
    D1[registry]
    D2[buildkite]
  end
  subgraph workloads
    W1[eks / gke / hetzner-k3s]
    W2[argocd]
    W3[rds · redis · messaging · s3]
  end
  W2 --> W1
  W1 --> F2 & F3
  W3 --> F2
  D1 --> F3
```

## Ownership

| Owns | What |
| --- | --- |
| Terraform | cloud resources, IAM, the ArgoCD install and root apps |
| The CD tool (Buildkite or GitHub Actions) | image builds and the prod promotion commit |
| ArgoCD | everything running in a cluster |
| The registry (`infra/access/`) | who can reach what |

No component crosses into another's area. ArgoCD never runs Terraform;
Terraform never deploys an app; CI never writes to a cluster.
