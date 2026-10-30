#!/usr/bin/env bash
# Slack Block Kit summary of drift: what drifted, what it costs, and the
# order to apply in (topological over depends_on, limited to drifted projects).
set -euo pipefail
results_dir=${1:?}
: "${SLACK_WEBHOOK_URL:?}" "${DRIFTED:?}" "${DRIFT_COUNT:?}" "${ERROR_COUNT:?}" "${RUN_URL:?}"

pr_url=$(gh api "repos/$GITHUB_REPOSITORY/pulls?head=${GITHUB_REPOSITORY%%/*}:${DRIFT_BRANCH:-drift/auto-detected}&state=open" --jq '.[0].html_url // empty' 2>/dev/null || true)
all=$(find "$results_dir" -name result.json -exec cat {} + | jq -s '.')

lines=""; total=0
for p in $DRIFTED; do
  name=${p%%(*}
  summary=$(jq -r --arg n "$name" '.[] | select(.project == $n) | .summary' <<<"$all")
  cost=""
  if [ -f "$results_dir/$name.cost.json" ]; then
    m=$(jq -r '.totalMonthlyCost // "0"' "$results_dir/$name.cost.json")
    cost=$(printf ' · monthly cost: $%.2f' "$m"); total=$(awk -v a="$total" -v b="$m" 'BEGIN{print a+b}')
  fi
  lines="$lines\n• \`$name\` — ${summary:-no result}$cost"
done

# Suggested apply order: DFS over depends_on, only drifted names, parents first.
declare -A deps seen
while IFS=$'\t' read -r n d; do deps[$n]=$d; done < <(yq -o=json '.' digger.yml | jq -r '.projects[] | [.name, ((.depends_on // []) | join(" "))] | @tsv')
drifted_names=$(for p in $DRIFTED; do case $p in *"(error)") ;; *) echo "$p";; esac; done)
order=()
visit() { local n=$1; [ -n "${seen[$n]:-}" ] && return; seen[$n]=1; for d in ${deps[$n]:-}; do grep -qx "$d" <<<"$drifted_names" && visit "$d"; done; order+=("$n"); }
for n in $drifted_names; do visit "$n"; done
apply_list=""; i=1
for n in "${order[@]}"; do apply_list="$apply_list\n$i. \`digger apply -p $n\`"; i=$((i+1)); done

payload=$(jq -n --arg h "*$DRIFT_COUNT* drifted · *$ERROR_COUNT* plan error(s) · <$RUN_URL|workflow run>${pr_url:+ · <$pr_url|drift PR>}" \
  --arg lines "$(printf "$lines")" --arg order "$(printf "$apply_list")" --arg total "$total" '
  {text: "Terraform drift detected", blocks: ([
    {type: "section", text: {type: "mrkdwn", text: ":rotating_light: *Terraform drift detected*"}},
    {type: "section", text: {type: "mrkdwn", text: $h}},
    {type: "divider"},
    {type: "section", text: {type: "mrkdwn", text: "*Drifted projects*\($lines)"}}]
    + (if ($total | tonumber) > 0 then [{type: "section", text: {type: "mrkdwn", text: "*Total monthly cost (drifted layers)*: $\($total)"}}] else [] end)
    + (if ($order | length) > 0 then [{type: "section", text: {type: "mrkdwn", text: "*Suggested apply order* (respecting depends_on)\($order)"}}] else [] end))}')

curl -sS -o /dev/null -w 'slack: %{http_code}\n' -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
