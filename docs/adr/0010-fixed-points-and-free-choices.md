# 0010 — Fix the source of truth, keep cloud, CD tool and language replaceable

**Context.** A platform monorepo outlives any single vendor choice. Teams
add a second cloud for a region or a customer, swap the CD tool, and ship
services in more than one language.

**Decision.** Three fixed points: GitHub (source, PRs, Terraform CI),
OpenTofu + Terragrunt (infrastructure), ArgoCD (clusters). Everything else
is a configuration or an adapter with at least two implementations in the
repository:

| Choice | Mechanism | Implemented |
| --- | --- | --- |
| cloud | `envs` map in `root.hcl`; auth step chosen from the instance path | AWS, GCP, Hetzner, GitHub |
| CD tool | `infra/delivery/lib/ci.sh` adapter around tool-neutral scripts; the tool itself is a Terraform layer | Buildkite, GitHub Actions |
| registry | `infra/delivery/lib/cloud.sh` | ECR, Artifact Registry, GHCR |
| language | app contract: Dockerfile, `make test lint`, `.platform/` | Go, Python |

**Consequences.**
- Adding an option is additive: one map entry, one adapter branch, one
  layer or one example app. Nothing shared is rewritten.
- Tool-specific features (Buildkite block fields, GitHub environments) are
  used, but behind the same scripts, so the graph reads the same.
- The cost is a small indirection layer that has to stay thin.
