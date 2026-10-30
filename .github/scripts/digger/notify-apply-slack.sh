#!/usr/bin/env bash
# One Slack message per apply run: outcome, who, which PR, per-project results.
set -euo pipefail
results_dir=${1:?}
: "${SLACK_WEBHOOK_URL:=}" "${PR_NUMBER:?}" "${OUTCOME:?}" "${RUN_URL:?}" "${ACTOR:?}"
[ -n "$SLACK_WEBHOOK_URL" ] || { echo "no Slack webhook configured; skipping"; exit 0; }

all=$(find "$results_dir" -name result.json -exec cat {} + | jq -s 'sort_by(.stage, .project)')
pr_url="https://github.com/$GITHUB_REPOSITORY/pull/$PR_NUMBER"
icon=$([ "$OUTCOME" = success ] && echo ":white_check_mark:" || echo ":x:")

payload=$(jq -n --arg icon "$icon" --arg outcome "$OUTCOME" --arg actor "$ACTOR" --arg pr "$pr_url" --arg run "$RUN_URL" --arg n "$PR_NUMBER" --argjson all "$all" '
  {
    text: "Terraform apply \($outcome) on PR #\($n) by \($actor)",
    blocks: ([
      {type: "section", text: {type: "mrkdwn", text: "\($icon) *Terraform apply \($outcome)* — <\($pr)|PR #\($n)> · requested by `\($actor)` · <\($run)|run>"}},
      {type: "divider"},
      {type: "section", text: {type: "mrkdwn", text: ([$all[] | "• `\(.project)` — \(if .result == "OK" then "✅" else "❌" end) \(.summary)"] | join("\n"))}}
    ] + ([$all[] | select(.result == "FAILED") | .output | split("\n") | map(select(startswith("Error:"))) | .[0:2] | join("\n")] | map(select(length > 0)) | if length > 0 then [{type: "context", elements: [{type: "mrkdwn", text: ("```" + (join("\n") | gsub("@"; "@​") | .[0:2500]) + "```")}]}] else [] end))
  }')

code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL")
[ "$code" = 200 ] || { echo "::warning::slack returned $code"; }
