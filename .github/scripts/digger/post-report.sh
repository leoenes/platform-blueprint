#!/usr/bin/env bash
# Merge every stage-*/result.json into one sticky PR comment.
# Hidden markers in the comment are the trust anchor the apply step reads back.
set -euo pipefail

results_dir=${1:?results dir}
: "${PR_NUMBER:?}" "${MODE:?}" "${HEAD_SHA:?}"
EXPECTED_COUNT=${EXPECTED_COUNT:-0}
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}
marker="<!-- tf-grouped-${MODE}-v1 -->"

all=$(find "$results_dir" -name result.json -exec cat {} + | jq -s 'sort_by(.stage, .project)')
count=$(jq 'length' <<<"$all")
failed=$(jq '[.[] | select(.result == "FAILED")] | length' <<<"$all")
missing=$((EXPECTED_COUNT - count))
[ $missing -lt 0 ] && missing=0

{
  echo "$marker"
  echo "<!-- tf-head-sha: $HEAD_SHA -->"
  if [ "$MODE" = plan ]; then
    jq -r '.[] | select(.result == "OK") | "<!-- tf-plan-fingerprint-v1 project=\(.project) head=\(.head_sha) sha256=\(.plan_hash) -->"' <<<"$all"
  fi
  echo
  echo "## Terraform ${MODE} — ${count} project(s), ${failed} failed, ${missing} missing"
  echo
  echo "| Stage | Project | Result | Summary |"
  echo "|---|---|---|---|"
  jq -r '.[] | "| \(.stage) | `\(.project)` | \(if .result == "OK" then "✅" elif .result == "SKIPPED" then "⏭️" else "❌" end) \(.result) | \(.summary) |"' <<<"$all"
  echo
  jq -r '.[] | select(.result == "FAILED" or (.summary | test("^Plan: [1-9]|^Apply complete"))) |
    "<details><summary><code>\(.project)</code> — \(.summary)</summary>\n\n```hcl\n\(.output | .[-6000:])\n```\n</details>\n"' <<<"$all"
  if [ "$MODE" = plan ]; then
    echo
    echo "Apply with \`digger apply\` (all) or \`digger apply -p <project>\` after review. Applies run against this exact plan; if anything changes, re-plan."
  fi
  [ $missing -gt 0 ] && echo -e "\n> ⚠️ ${missing} project(s) produced no result. Do not apply from this report."
} > /tmp/report.md

existing=$(gh api "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" --paginate \
  --jq "[.[] | select(.user.type == \"Bot\" and (.body | contains(\"$marker\")))] | last | .id // empty")
if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$existing" -F body=@/tmp/report.md > /dev/null
else
  gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" -F body=@/tmp/report.md > /dev/null
fi

echo "failed-count=$((failed + missing))" >> "$GITHUB_OUTPUT"
