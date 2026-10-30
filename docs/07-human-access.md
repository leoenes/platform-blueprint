# Human access registry

One YAML entry per person, in git, reviewed like any other change, and read
by every system that grants access.

```mermaid
flowchart LR
  U[infra/access/users.yaml] --> R[modules/human_access<br/>pure Terraform resolver]
  T[infra/access/teams.yaml] --> R
  R -->|catalog| IC[IAM Identity Center]
  R -->|catalog| GH[GitHub org + teams]
  R -->|catalog| BK[Buildkite teams]
  R -->|catalog| VPN[VPN groups]
  R -->|catalog| OBS[Observability roles]
  R -->|catalog| SL[Slack channels]
  D[infra/access/databases-&lt;env&gt;.yaml] --> K8S[in-cluster DB access reconciler]
```

## Rules

| Rule | Why |
| --- | --- |
| Identity, SSO and database grants are never inherited from a team | the risky things stay explicit per person |
| A team bundle may carry lists: GitHub teams, VPN groups, Slack channels, SaaS roles | low-risk, high-volume access is where inheritance saves time |
| An explicit user field replaces the bundle's | no surprising unions |
| `access.<service>: null` disables the service for that person | opt out without deleting the bundle |
| Slack is additive | nobody is removed from a channel by a refactor |
| Unknown team or duplicate username fails the plan | the registry is validated, not trusted |

```mermaid
flowchart LR
  TB["team bundle<br/>github: {role: member, teams: [backend]}<br/>vpn: {groups: [eks-nonprod]}"] --> MERGE{resolve}
  UO["user override<br/>github: {role: admin}<br/>vpn: null"] --> MERGE
  MERGE --> OUT["github: {role: admin, teams: [backend]}<br/>vpn: disabled"]
```

## One change, every consumer

Every consumer layer lists the registry files and the resolver in its
`include_patterns`. A PR that onboards a person shows the plan for the
GitHub org, Buildkite, the VPN, the observability roles, the Slack invites
and Identity Center in one comment, applied in one `digger apply`. Removing
a person is deleting a block; every consumer plans the removal.

## Database access

Grants live in a per-environment file and are reconciled by a small
Deployment in the cluster.

```mermaid
stateDiagram-v2
  [*] --> Validate
  Validate --> Audit: file valid
  Validate --> Suspend: unknown DB / bad level / live access on disabled env
  Audit --> Roles: audit prerequisites ok
  Roles --> Grants: one managed role per person
  Grants --> Revoke: exact grants applied
  Revoke --> Sleep: downgraded or removed people revoked, sessions terminated
  Sleep --> Validate: every 5 minutes
  Roles --> Suspend: any failure
  Grants --> Suspend: any failure
  Suspend --> Validate: next cycle
  note right of Suspend: all managed human roles suspended (fail closed)
```

- Passwords are cleared every cycle. People connect with 15-minute IAM
  tokens over TLS.
- `default_transaction_read_only` is a guardrail; ACLs are authoritative.
- MFA is enforced in Identity Center, which has no API for it, and is the
  one manual step documented.
