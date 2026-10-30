#!/usr/bin/env bash
# Render the per-account snapshots as one Slack message.
set -euo pipefail
dir=${1:?}
: "${SLACK_WEBHOOK_URL:=}"
[ -n "$SLACK_WEBHOOK_URL" ] || { echo "no Slack webhook configured; skipping"; exit 0; }
PRIMARY_NAMES=${PRIMARY_NAMES:-}
TOP_N=${TOP_N:-10}
MIN_SHOW=${MIN_SHOW:-50}

money() { awk -v n="$1" 'BEGIN{ s=sprintf("%.2f", n); while (s ~ /[0-9][0-9][0-9][0-9]/) sub(/[0-9][0-9][0-9][.,]/, ",&", s); sub(/,,/, ",", s); printf "$%s", s }'; }
trend() { awk -v l="$1" -v p="$2" 'BEGIN{ d=l-p; if (p==0) print "🆕"; else if (d<0.005 && d>-0.005) print "➖"; else if (d>0) print "📈"; else print "📉" }'; }

account_block() {
  local f=$1
  local name id last prev pct
  name=$(jq -r .accountName "$f"); id=$(jq -r .accountId "$f")
  last=$(jq -r .lastMonthAmount "$f"); prev=$(jq -r .prevMonthAmount "$f")
  pct=$(awk -v l="$last" -v p="$prev" 'BEGIN{ if (p>0) printf "%+.1f%%", (l-p)/p*100; else print "n/a" }')
  table=$(jq -r --argjson top "$TOP_N" --argjson min "$MIN_SHOW" '
    .services | map(. + {l: (.last|tonumber), p: (.prev|tonumber)})
    | (to_entries | map(select(.key < $top or .value.l >= $min)) | map(.value)) as $show
    | (map(.l) | add) - ($show | map(.l) | add) as $rest
    | ($show | map("\(.name | sub("^(Amazon|AWS) "; "") | .[0:34] | . + (" " * (34 - length)))  \(.l | tostring | .[0:10])")) + (if $rest > 0.005 then ["Other (\(length - ($show|length)) svcs)                          \($rest)"] else [] end)
    | join("\n")' "$f")
  jq -n --arg t "*$name* \`$id\` · *$(money "$last")* $(trend "$last" "$prev") _$(money "$(awk -v l="$last" -v p="$prev" 'BEGIN{print l-p}')") ($pct) vs prev_" --arg tbl "$table" \
    '[{type: "divider"}, {type: "section", text: {type: "mrkdwn", text: ($t + "\n```" + $tbl + "```")}}]'
}

first=$(find "$dir" -name "*.json" | sort | head -1)
month=$(jq -r .lastMonthStart "$first")
label=$(date -u -d "$month" +"%B %Y" 2>/dev/null || date -u -j -f %F "$month" +"%B %Y")
primary="[]"; other="[]"
for f in "$dir"/*.json; do
  n=$(jq -r .accountName "$f")
  if grep -qw "$n" <<<"$PRIMARY_NAMES"; then primary=$(jq -c --argjson b "$(account_block "$f")" '. + $b' <<<"$primary"); else other=$(jq -c --argjson b "$(account_block "$f")" '. + $b' <<<"$other"); fi
done
total_last=$(jq -s 'map(.lastMonthAmount) | add' "$dir"/*.json)
total_prev=$(jq -s 'map(.prevMonthAmount) | add' "$dir"/*.json)

payload=$(jq -n --arg label "$label" --argjson p "$primary" --argjson o "$other" \
  --arg total "*Total: $(money "$total_last")* $(trend "$total_last" "$total_prev") vs $(money "$total_prev")" '
  {text: "AWS cost snapshot \($label)", blocks: ([
    {type: "header", text: {type: "plain_text", text: "💰 AWS Cost Snapshot — \($label)"}},
    {type: "context", elements: [{type: "mrkdwn", text: "Last closed month vs the one before · unblended cost"}]},
    {type: "section", text: {type: "mrkdwn", text: "⭐ *Primary accounts*"}}] + $p
    + (if ($o | length) > 0 then [{type: "section", text: {type: "mrkdwn", text: "🗄️ *Other accounts*"}}] + $o else [] end)
    + [{type: "divider"}, {type: "section", text: {type: "mrkdwn", text: $total}}])}')
curl -sS -o /dev/null -w 'slack: %{http_code}\n' -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
