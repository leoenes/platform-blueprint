# 0005 — Drift is a PR, not a dashboard

**Context.** Drift reports in a dashboard or a channel are read once and
lost. Reconciling needs the plan, the approval path and the apply command in
one place.

**Decision.** Nightly plans of every project. Drift and errors are written to
one branch and one PR that is updated in place, closed when clean, and
exempt from PR-size rules only when it originates in this repository. The
PR body carries an allow-list the apply authorizer checks. Slack gets a
summary with cost and the apply order.

**Consequences.**
- Reconciling drift is `digger apply -p <project>` from the drift PR, with
  the same guards as any apply.
- Missing results are errors, never clean.
- A drifted layer shows its monthly cost, which prioritises the response.
