# 0009 — OIDC everywhere, no static cloud credentials

**Context.** Long-lived access keys in CI secrets are the most common
breach path and the hardest thing to rotate.

**Decision.** GitHub Actions and Buildkite exchange OIDC tokens for AWS
roles. One entry role in the deployment account chain-assumes a per-account
role whose policy is an explicit service allow-list with denies on IAM users,
keys and the organization. Buildkite's prod role trusts only
`pipeline=platform, branch=main` session tags. Provider tokens for SaaS live
in Secrets Manager and are read into the environment at run time.

**Consequences.**
- Nothing to rotate; revocation is a trust-policy edit.
- A PR from a fork gets no credentials at all.
- Local work uses SSO profiles; read-only plans refuse ambient credentials.
