#!/usr/bin/env bash
# Run one project (plan|apply); always write result.json.
# Plan: keyed sha256 of the semantic plan → PR comment. Apply: re-plan, require
# the same hash, then apply the saved plan file.
set -uo pipefail

: "${PROJECT:?}" "${DIR:?}" "${MODE:?}" "${STAGE:?}" "${SNAPSHOT_HEAD_SHA:?}"
OUT_DIR=${OUT_DIR:-/tmp/project-out}
mkdir -p "$OUT_DIR"
key=${PLAN_FINGERPRINT_KEY:-}
unset PLAN_FINGERPRINT_KEY

write_result() { # result summary output [plan_hash]
  jq -n --arg project "$PROJECT" --arg dir "$DIR" --arg mode "$MODE" --argjson stage "$STAGE" \
    --arg result "$1" --arg summary "$2" --rawfile output "$3" --arg head "$SNAPSHOT_HEAD_SHA" --arg hash "${4:-}" \
    '{project:$project, dir:$dir, mode:$mode, stage:$stage, result:$result, summary:$summary, output:$output, head_sha:$head, plan_hash:$hash}' \
    > "$OUT_DIR/result.json"
}

[ -d "$DIR" ] || { echo "directory missing" > "$OUT_DIR/out.txt"; write_result FAILED "directory not found" "$OUT_DIR/out.txt"; exit 1; }
if grep -qE '^skip\s*=\s*true' "$DIR/terragrunt.hcl"; then
  : > "$OUT_DIR/out.txt"; write_result SKIPPED "skip = true" "$OUT_DIR/out.txt"; exit 0
fi

plan_file=$RUNNER_TEMP/plan-$PROJECT.tfplan
raw=$OUT_DIR/raw.txt
out=$OUT_DIR/out.txt

# Lines stripped from PR output.
NOISE='^(Refreshing state|Reading\.\.\.|Read complete|Acquiring state lock|Releasing state lock|.*terragrunt-cache.*|.*Initializing (the backend|provider plugins|modules).*|.*has been successfully initialized.*)'

(cd "$DIR" && terragrunt plan -out="$plan_file" -no-color) > "$raw" 2>&1
rc=$?
grep -vE "$NOISE" "$raw" | awk '/will perform the following actions:|No changes\./{p=1} p' > "$out"
[ -s "$out" ] || cp "$raw" "$out"

if [ $rc -ne 0 ]; then
  if grep -qE '^Error: Error acquiring the state lock$' "$raw"; then
    write_result FAILED "state lock unavailable after 15m; another run holds it" "$out"
  else
    write_result FAILED "plan failed" "$out"
  fi
  exit $rc
fi

summary=$(grep -oE 'Plan: [0-9]+ to (import, [0-9]+ to )?add, [0-9]+ to change, [0-9]+ to destroy\.' "$raw" | tail -1)
[ -n "$summary" ] || summary="No changes"

# Semantic fingerprint: non-no-op changes, sorted.
semantic=$(cd "$DIR" && terragrunt show -json "$plan_file" 2>/dev/null | jq -S -c '{
  resource_changes: ([.resource_changes[]? | select(.change.actions != ["no-op"]) | {address, actions: .change.actions, after: .change.after}] | sort_by(.address)),
  output_changes: ([.output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) | {name: .key, actions: .value.actions}] | sort_by(.name))
}')
hash=$( { printf '%s\0' "$key"; printf '%s' "$semantic"; } | sha256sum | cut -c1-64)

if [ "$MODE" = plan ]; then
  write_result OK "$summary" "$out" "$hash"
  exit 0
fi

# ── apply ────────────────────────────────────────────────────────────────────
expected=${EXPECTED_PLAN_HASH:-}
if [ -z "$expected" ]; then
  write_result FAILED "approved plan missing: run \`digger plan\` and get a review first" "$out"; exit 1
fi
if [ "$hash" != "$expected" ]; then
  write_result FAILED "approved plan changed: the world moved since review, re-plan and re-review" "$out"; exit 1
fi
if [ "$semantic" = '{"output_changes":[],"resource_changes":[]}' ]; then
  write_result OK "no changes" "$out" "$hash"; exit 0
fi

(cd "$DIR" && terragrunt apply -auto-approve -no-color "$plan_file") > "$raw" 2>&1
rc=$?
grep -vE "$NOISE" "$raw" > "$out"
if [ $rc -ne 0 ]; then
  if grep -q 'Saved plan is stale' "$raw"; then write_result FAILED "saved plan stale; re-plan" "$out"
  else write_result FAILED "apply failed; state may be partially changed, inspect before retrying" "$out"; fi
  exit $rc
fi
summary=$(grep -oE 'Apply complete! Resources: .*' "$raw" | tail -1)
write_result OK "${summary:-applied}" "$out" "$hash"
