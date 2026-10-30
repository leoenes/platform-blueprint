#!/usr/bin/env bash
# Two channels, two audiences:
#   deploys   — promotions-ready, prod-committed, prod-rejected (people who ship)
#   failures  — build-failed (people who fix the platform)
set -euo pipefail
kind=${1:?} ; shift
apps=("$@")
cd "$(dirname "$0")/../../.."
. infra/delivery/lib/ci.sh
build="<$(ci_build_url)|build>"
who=$(ci_actor)

case $kind in
  promotions-ready) hook=$SLACK_WEBHOOK_DEPLOYS;  text=":white_check_mark: *Ready to promote* — ${apps[*]} · $build · by $who\nApprove in $(ci_name); each app has its own gate." ;;
  prod-committed)   hook=$SLACK_WEBHOOK_DEPLOYS;  text=":rocket: *${apps[0]} promoted to prod* by $(ci_approver) · $build" ;;
  prod-rejected)    hook=$SLACK_WEBHOOK_DEPLOYS;  text=":no_entry: *${apps[0]} promotion rejected* by $(ci_approver) · $build" ;;
  build-failed)     hook=$SLACK_WEBHOOK_FAILURES; text=":x: *main build failed* — step \`${apps[0]:-?}\` · $build · last commit by $who" ;;
  *) echo "unknown kind $kind" >&2; exit 1 ;;
esac

jq -n --arg t "$(printf "$text")" '{text: $t}' \
  | curl -sS -o /dev/null -w 'slack: %{http_code}\n' -X POST -H 'Content-type: application/json' --data @- "$hook"
