# 0001 — OpenTofu as engine, Terragrunt for path-derived configuration

**Context.** Dozens of Terraform roots across seven accounts and two
regions. Copying backend blocks and provider configuration per root had
already produced one wrong-account apply.

**Decision.** OpenTofu (`terraform_binary = "tofu"`) under Terragrunt. The
instance path encodes stage, leader and region; `root.hcl` derives account,
backend, role and lock timeout from it. Instance files hold inputs only.

**Consequences.**
- A new environment is a directory. Nothing shared is edited.
- Module logic stays in the layer; wrapper files cannot hide behaviour.
- One lock timeout, one state key scheme, one auth path for the whole repo.
- Costs a `.terragrunt-cache` per instance and the `//` source trick to keep
  relative module paths working.
