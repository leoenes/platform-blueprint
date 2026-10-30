# 0006 — Trunk-based delivery; prod is a reviewed commit

**Context.** Release branches and environment branches drift from each
other and hide what is actually in prod.

**Decision.** One branch. Every merge builds immutable `rel-<sha>` images for
the affected apps. Nonprod follows the registry automatically. Prod promotion is a
gate (Buildkite block step or GitHub environment approval, with optional backup) that results in a
commit pinning `image.tag` in the prod overlay, pushed by a dedicated GitHub
App. ArgoCD renders prod at the SHA inside the tag.

**Consequences.**
- `git log apps/<app>/.platform/values-prod-*.yaml` is the prod release history.
- A merged change cannot reach prod without the promotion, even if it edits
  prod values.
- A regression guard and superseded-block cleanup keep prod monotonic.
- Needs two GitHub Apps and two AWS roles with disjoint permissions.
