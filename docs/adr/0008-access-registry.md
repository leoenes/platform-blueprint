# 0008 — One registry file drives all human access

**Context.** Onboarding touched six systems by hand; offboarding missed
some of them.

**Decision.** `infra/access/users.yaml` and `infra/access/teams.yaml`, resolved by a
pure Terraform module into one catalog per person, consumed by every
provider layer. Identity, SSO and database grants are explicit per person;
list-like access may come from team bundles. Database grants are reconciled
in-cluster and fail closed.

**Consequences.**
- One PR shows the plan for every system a person touches.
- Removing a person is deleting a block; every consumer plans the removal.
- Validation (unknown team, duplicate username, bad grant) fails the plan
  before anything is granted.
