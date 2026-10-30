#!/usr/bin/env bash
# Attach the monthly cost of each drifted layer (Infracost). Best effort:
# missing key or CLI just skips the step.
set -u
results_dir=${1:?}
[ -n "${INFRACOST_API_KEY:-}" ] || { echo "::warning::INFRACOST_API_KEY not set"; exit 0; }
command -v infracost >/dev/null || { echo "::warning::infracost not installed"; exit 0; }
for p in ${DRIFTED:-}; do
  name=${p%%(*}
  dir=$(yq -r ".projects[] | select(.name == \"$name\") | .dir" digger.yml)
  [ -d "$dir" ] || continue
  infracost breakdown --path "$dir" --terraform-binary tofu --format json --out-file "$results_dir/$name.cost.json" >/dev/null 2>&1 || true
done
