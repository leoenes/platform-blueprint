# 0003 — Plan and apply from the PR, merge after

**Context.** Apply-on-merge leaves main wrong when the apply fails and
hides who approved what.

**Decision.** `pull_request` plans every impacted project. A `digger apply`
comment applies from the PR, bound to the merge commit at comment time,
ordered by dependency depth. The PR is merged after a successful apply. A
reminder nags about applied-but-open PRs.

**Consequences.**
- Main always describes reality; a failed apply is visible in the PR.
- Approval, plan and apply are one audit trail in one place.
- Requires guarding the apply: approval on head, mergeable, commenter
  permission, no re-runs, per-state queueing.
