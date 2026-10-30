# Terraform and Terragrunt

## The path is the configuration

```
infra/terraform/layers/<category>/<layer>/environments/<stage>/<leader>/<region>/terragrunt.hcl
```

`root.hcl` splits that path and derives everything else from one `envs` map:

| From the path | Derived |
| --- | --- |
| `<stage>/<leader>` | tenant: cloud (`aws`, `gcp`, `hetzner`, `github`), id (account, project or org) |
| tenant | state backend (`s3` or `gcs`), bucket, lock table |
| tenant | SSO profile locally, IAM role to chain-assume in CI (AWS only) |
| `<category>/<layer>` | Terraform source directory and state key |

`<leader>` is a country for the primary cloud (`uk`, `us`), `<cloud>-<area>`
for other clouds (`gcp-eu`, `hetzner-eu`), or a shared role.

An instance file contains only inputs:

```hcl
include "root" { path = find_in_parent_folders("root.hcl") }
inputs = { cluster_name = "nonprod-uk", cluster_version = "1.37", vpc_tier = "nonproduction" }
```

## Why Terragrunt

- One backend block for the whole repo, not one per root.
- Account, role and region cannot be mistyped: they come from where the file is.
- `terraform { source = ".../infra/terraform//layers/<category>/<layer>" }`
  keeps `../../../modules/*` references working inside the cache.
- `-lock-timeout=15m` lives in one place so Digger applies, the drift cron and
  a laptop plan queue instead of failing on each other.

## Why OpenTofu

Drop-in replacement for Terraform under an open licence, with state
encryption. Pinned in `mise.toml` so laptops and CI run the same binary.

## State

- AWS: bucket per account, `platform-<account_id>-tfstate`, versioned,
  KMS-encrypted, TLS-only, DynamoDB lock table next to it.
- GCP: GCS bucket per project, versioned, with object-level locking.
- Providers without a state service (Hetzner, GitHub): the organization
  account's bucket, under their own key prefix.
- Key: `<env>/<region>/<category>/<layer>/terraform.tfstate` everywhere.
- Created once per tenant by `infra/terraform/setup` with local credentials;
  the only thing ever applied outside CI.

## Authentication

| Cloud | Laptop | CI |
| --- | --- | --- |
| AWS | SSO profile named after the account; `make plan-ro` forces the `-readonly` profile and refuses ambient credentials | GitHub OIDC into the deployment account, then Terragrunt `iam_role` chain-assumes `gh-actions-terraform` in the target account |
| GCP | `gcloud auth application-default login` | Workload Identity Federation (`google-github-actions/auth`), no key file |
| Hetzner, Cloudflare, GitHub | token in the shell from the secrets store | token read from the secrets store at run time, masked, never a repo secret |

The CI role in each AWS account is an explicit service allow-list with a deny
on IAM users, access keys and the organization. There is no
`AdministratorAccess` in the pipeline. The stage workflow picks the auth step
from the instance path, so adding a cloud is one more conditional step.

## Conventions that avoid drift

- Cluster KMS administrators pinned to account root, not the caller ARN
  (otherwise every alternation between SSO and CI applies showed a diff).
- Access to EKS is declared through access entries, never inherited from
  whoever ran `apply`.
- Stable resource names where a Kubernetes manifest references them
  (Karpenter node role).
