#!/usr/bin/env bash
# Turn "which files changed" into "which projects run, in which stage".
#
# Inputs (env): EVENT_NAME, COMMENT_BODY, CHANGED_FILES, SELECTION_SCOPE (pr|drift)
# Outputs ($GITHUB_OUTPUT): mode, has-projects, stage<N>-matrix, stage<N>-count
#
# Rules:
#   - a project is impacted when a changed file is under its dir or matches
#     one of its include_patterns
#   - `digger apply -p X` overrides diff detection with exactly X
#   - depends_on never widens the set; it only orders applies
#   - PR plans are flattened to stage 0 (plans are read-only, run them all at once)
#   - applies and drift use depth(p) = 1 + max(depth(parents)) as the stage
set -euo pipefail

MAX_STAGE=${MAX_STAGE:-3}
SELECTION_SCOPE=${SELECTION_SCOPE:-pr}
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}

mode=plan
target=""
if [ "${EVENT_NAME:-}" = "issue_comment" ]; then
  if grep -qE '^digger[[:space:]]+apply\b' <<<"${COMMENT_BODY:-}"; then mode=apply
  elif grep -qE '^digger[[:space:]]+plan\b' <<<"${COMMENT_BODY:-}"; then mode=plan
  else echo "has-projects=false" >> "$GITHUB_OUTPUT"; echo "mode=none" >> "$GITHUB_OUTPUT"; exit 0; fi
  target=$(grep -oE '\-p[[:space:]]+[A-Za-z0-9_-]+' <<<"${COMMENT_BODY:-}" | head -1 | awk '{print $2}' || true)
fi

CFG_JSON=$(yq -o=json '.' digger.yml)

declare -A DIR DEPS INDEX
# index before deps: tabs collapse in `read`, so the possibly-empty field goes last
while IFS=$'\t' read -r name dir idx deps; do
  DIR["$name"]=$dir; INDEX["$name"]=$idx; DEPS["$name"]=${deps:-}
done < <(jq -r '.projects | to_entries[] | [.value.name, .value.dir, .key, ((.value.depends_on // []) | join(" "))] | @tsv' <<<"$CFG_JSON")

glob_to_regex() {
  local g=$1
  # shellcheck disable=SC2001,SC2016  # regex metacharacters are escaped literally
  g=$(sed -e 's/[.+^$(){}|\\]/\\&/g' <<<"$g")
  g=${g//\*\*/__DS__}
  g=${g//\*/[^/]*}
  g=${g//\?/[^/]}
  g=${g//__DS__/.*}
  printf '^%s$' "$g"
}

IMPACTED=()
if [ -n "$target" ]; then
  [ -n "${DIR[$target]:-}" ] || { echo "::error::unknown project $target"; exit 1; }
  IMPACTED=("$target")
elif [ "$SELECTION_SCOPE" = "drift" ]; then
  mapfile -t IMPACTED < <(jq -r '.projects[] | select(.drift_detection == true) | .name' <<<"$CFG_JSON")
else
  mapfile -t files < <(printf '%s\n' "${CHANGED_FILES:-}" | sed '/^$/d')
  while IFS=$'\t' read -r name dir patterns_b64; do
    hit=0
    for f in "${files[@]}"; do
      [[ "$f" == "${dir%/}/"* ]] && { hit=1; break; }
      while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        [[ "$f" =~ $(glob_to_regex "$pat") ]] && { hit=1; break 2; }
      done < <(base64 -d <<<"$patterns_b64")
    done
    [ $hit = 1 ] && IMPACTED+=("$name")
  done < <(jq -r '.projects[] | [.name, (.dir // ""), ((.include_patterns // []) | join("\n") | @base64)] | @tsv' <<<"$CFG_JSON")
fi

echo "mode=$mode" >> "$GITHUB_OUTPUT"
if [ ${#IMPACTED[@]} -eq 0 ]; then
  echo "has-projects=false" >> "$GITHUB_OUTPUT"
  for s in $(seq 0 "$MAX_STAGE"); do echo "stage$s-count=0" >> "$GITHUB_OUTPUT"; echo "stage$s-matrix={\"include\":[]}" >> "$GITHUB_OUTPUT"; done
  exit 0
fi
echo "has-projects=true" >> "$GITHUB_OUTPUT"

in_set() { local p=$1; for x in "${IMPACTED[@]}"; do [ "$x" = "$p" ] && return 0; done; return 1; }

declare -A DEPTH
depth() {
  local p=$1 trail=${2:-}
  case " $trail " in *" $p "*) echo "::error::dependency cycle at $p"; exit 1 ;; esac
  [ -n "${DEPTH[$p]:-}" ] && { echo "${DEPTH[$p]}"; return; }
  local d=0 parent pd
  for parent in ${DEPS[$p]}; do
    in_set "$parent" || continue
    pd=$(depth "$parent" "$trail $p")
    [ $((pd + 1)) -gt $d ] && d=$((pd + 1))
  done
  DEPTH[$p]=$d; echo "$d"
}

declare -A STAGE_OF
for p in "${IMPACTED[@]}"; do
  s=$(depth "$p")
  if [ "$mode" = plan ] && [ "$SELECTION_SCOPE" = pr ]; then s=0; fi
  if [ "$s" -gt "$MAX_STAGE" ]; then echo "::error::$p needs stage $s > MAX_STAGE=$MAX_STAGE; add a stage to the workflow"; exit 1; fi
  STAGE_OF[$p]=$s
done

for s in $(seq 0 "$MAX_STAGE"); do
  matrix='{"include":[]}'; count=0
  for p in $(printf '%s\n' "${IMPACTED[@]}" | sort); do
    [ "${STAGE_OF[$p]}" = "$s" ] || continue
    matrix=$(jq -c --arg n "$p" --arg d "${DIR[$p]}" --argjson i "${INDEX[$p]}" --arg scope "$SELECTION_SCOPE" \
      '.include += [{project: $n, dir: $d} + (if $scope == "drift" then {shard: $i} else {} end)]' <<<"$matrix")
    count=$((count + 1))
  done
  echo "stage$s-matrix=$matrix" >> "$GITHUB_OUTPUT"
  echo "stage$s-count=$count" >> "$GITHUB_OUTPUT"
  echo "stage $s: $count project(s)" >&2
done
