#!/usr/bin/env bash
# Classify results; a missing result is an error, never clean.
set -euo pipefail
results_dir=${1:?}
EXPECTED_COUNT=${EXPECTED_COUNT:-0}
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}

all=$(find "$results_dir" -name result.json -exec cat {} + | jq -s '.')
found=$(jq 'length' <<<"$all")

# drift = OK with "Plan: ..." (outputs-only ignored); error = FAILED; else clean
drifted=$(jq -r '.[] | select(.result == "OK" and (.summary | test("^Plan: "))) | .project' <<<"$all")
errored=$(jq -r '.[] | select(.result == "FAILED") | "\(.project)(error)"' <<<"$all")
missing=$((EXPECTED_COUNT - found))
[ $missing -gt 0 ] && errored="$errored"$'\n'"project-inventory-error(error)"

drift_count=$(grep -c . <<<"$drifted" || true)
error_count=$(grep -c . <<<"$errored" || true)

{
  echo "drift-count=$drift_count"
  echo "error-count=$error_count"
  echo "drifted=$(printf '%s\n%s\n' "$drifted" "$errored" | sed '/^$/d' | tr '\n' ' ' | sed 's/ $//')"
} >> "$GITHUB_OUTPUT"
echo "drift=$drift_count error=$error_count found=$found expected=$EXPECTED_COUNT" >&2
