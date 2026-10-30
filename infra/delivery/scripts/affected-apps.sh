#!/usr/bin/env bash
# Print the apps affected by the diff against $1, one per line.
# Language-agnostic: an app is any directory under apps/ with a Dockerfile.
# It is affected when its own directory, a path it lists in deps.txt, or the
# shared service chart changed.
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
