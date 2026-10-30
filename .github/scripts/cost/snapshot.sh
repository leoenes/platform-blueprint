#!/usr/bin/env bash
# Cost Explorer: total + per-service for the last two closed months.
set -euo pipefail
out=${1:?}
: "${ACCOUNT_ID:?}" "${ACCOUNT_NAME:?}"
mkdir -p "$(dirname "$out")"

first_of_this=$(date -u +%Y-%m-01)
last_start=$(date -u -d "$first_of_this -1 month" +%F 2>/dev/null || date -u -j -v-1m -f %F "$first_of_this" +%F)
prev_start=$(date -u -d "$first_of_this -2 month" +%F 2>/dev/null || date -u -j -v-2m -f %F "$first_of_this" +%F)

by_service() { # start end
  aws ce get-cost-and-usage --time-period Start="$1",End="$2" --granularity MONTHLY --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[].{name: Keys[0], amount: Metrics.UnblendedCost.Amount}' --output json
}
last=$(by_service "$last_start" "$first_of_this")
prev=$(by_service "$prev_start" "$last_start")

jq -n --arg id "$ACCOUNT_ID" --arg name "$ACCOUNT_NAME" --arg ls "$last_start" --arg ps "$prev_start" --argjson last "$last" --argjson prev "$prev" '
  ($last | map({key: .name, last: .amount})) as $L | ($prev | map({key: .name, prev: .amount})) as $P
  | (($L + $P) | group_by(.key) | map({name: .[0].key,
       last: ((map(.last) | map(select(. != null)) | first) // "0"),
       prev: ((map(.prev) | map(select(. != null)) | first) // "0")})
     | sort_by(.last | tonumber) | reverse) as $services
  | {accountId: $id, accountName: $name, lastMonthStart: $ls, prevMonthStart: $ps,
     lastMonthAmount: ($services | map(.last | tonumber) | add // 0),
     prevMonthAmount: ($services | map(.prev | tonumber) | add // 0),
     services: $services}' > "$out"
