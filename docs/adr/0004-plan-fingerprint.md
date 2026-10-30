# 0004 — Apply only the plan that was reviewed

**Context.** Between review and apply the world can move: console changes,
a parent layer's outputs, provider defaults. A fresh plan at apply time is not
what the reviewer saw.

**Decision.** Reduce each plan to its semantic changes (`show -json`,
non-no-op resource and output changes, sorted), hash it with a secret key,
publish the hash as a hidden marker in the PR comment. At apply, re-plan
from the same snapshot, require an identical hash, then apply the saved plan
file.

**Consequences.**
- "Approved plan changed" is a hard stop with a clear next step: re-plan.
- Refresh-only drift and ordering noise do not break the match.
- The key keeps a PR author from forging the marker.
