#!/usr/bin/env bash
# Keep the plan sticky comment honest while a plan is running, so nobody
# applies from a report that is being rewritten.
set -euo pipefail
: "${PR_NUMBER:?}"
state=${1:?start|failed}
marker="<!-- tf-grouped-plan-v1 -->"

case $state in
  start)  body="$marker\n\n🟡 **Terraform plan in progress** — results will replace this comment." ;;
  failed) body="$marker\n\n🔴 **Terraform plan did not complete.** Do not apply from stale results; fix and push again." ;;
  *) echo "unknown state $state" >&2; exit 1 ;;
esac

existing=$(gh api "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" --paginate \
  --jq "[.[] | select(.user.type == \"Bot\" and (.body | contains(\"$marker\")))] | last | .id // empty")
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$existing" -f body="$(printf "$body")" > /dev/null
else
  gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" -f body="$(printf "$body")" > /dev/null
fi
