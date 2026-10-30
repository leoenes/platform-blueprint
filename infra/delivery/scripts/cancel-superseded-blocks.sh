#!/usr/bin/env bash
# Buildkite only: reject blocked promotions of <app> whose commit is an
# ancestor of <sha>. (GitHub Actions: handled by the concurrency group.)
set -euo pipefail
app=${1:?} sha=${2:?}
: "${BUILDKITE_API_TOKEN:?}"
api="https://api.buildkite.com/v2/organizations/${BUILDKITE_ORGANIZATION_SLUG}/pipelines/${BUILDKITE_PIPELINE_SLUG}"

curl -sS -H "Authorization: Bearer $BUILDKITE_API_TOKEN" "$api/builds?state[]=blocked&branch=main&per_page=50" \
| jq -r --arg app "$app" '.[] | select(.number != (env.BUILDKITE_BUILD_NUMBER | tonumber)) | "\(.number) \(.commit) \([.jobs[] | select(.type == "manual" and .step_key == "block-\($app)" and .state == "blocked") | .id] | first // "")"' \
| while read -r number commit job_id; do
    [ -n "$job_id" ] || continue
    git merge-base --is-ancestor "$commit" "$sha" || continue
    echo "build $number ($commit) superseded by $sha; rejecting"
    curl -sS -o /dev/null -X PUT -H "Authorization: Bearer $BUILDKITE_API_TOKEN" -H 'Content-Type: application/json' \
      "$api/builds/$number/jobs/$job_id/unblock" \
      --data "{\"fields\": {\"decision-$app\": \"reject\", \"backup-$app\": \"skip\"}}"
  done
