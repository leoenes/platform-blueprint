# 0002 — One AWS account per blast radius, state per account

**Context.** Network, organization, security tooling, CI, nonprod and prod
have different change rates and different people who should be able to break
them.

**Decision.** Separate accounts for organization, network, security,
deployment and each stage+region. Each account owns its state bucket, lock
table and KMS key. Workload accounts receive subnets by RAM share and never
own a VPC.

**Consequences.**
- A bad apply in nonprod cannot touch prod state or prod networking.
- CI needs a role per account and chain-assume; handled once in `root.hcl`.
- Cross-account lookups use tags and data sources, not remote state, so
  layers do not couple on state file paths.
