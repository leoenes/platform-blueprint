#!/usr/bin/env bash
# Apps affected by the diff against $1 (one per line). An app = a directory
# with a Dockerfile; affected via its dir, deps.txt paths or the service chart.
set -euo pipefail
base=${1:?base ref}
changed=$(git diff --name-only "$base"...HEAD)
for dockerfile in apps/*/Dockerfile; do
  app=$(basename "$(dirname "$dockerfile")")
  paths=("apps/$app/" "infra/helm-charts/service/")
  [ -f "apps/$app/deps.txt" ] && mapfile -t -O "${#paths[@]}" paths < "apps/$app/deps.txt"
  for p in "${paths[@]}"; do
    if grep -q "^${p%/}/" <<<"$changed"; then echo "$app"; break; fi
  done
done
