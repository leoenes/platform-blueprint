#!/usr/bin/env bash
# Sticky drift PR: plans as evidence plus a hidden apply allow-list; closed when clean.
set -euo pipefail
action=${1:?update|close}
results_dir=${2:-results}
: "${GH_TOKEN:?}" "${DRIFT_BRANCH:?}"
REPORT=DRIFT_REPORT.md
remote="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

find_pr() {
  gh api "repos/$GITHUB_REPOSITORY/pulls?head=${GITHUB_REPOSITORY%%/*}:${DRIFT_BRANCH}&state=open" --jq '.[0].number // empty'
}

if [ "$action" = close ]; then
  pr=$(find_pr)
  [ -n "$pr" ] || exit 0
  gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$pr/comments" -f body="✅ Drift cleared on $(date -u +%F). Closing." > /dev/null
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/pulls/$pr" -f state=closed > /dev/null
  gh api -X DELETE "repos/$GITHUB_REPOSITORY/git/refs/heads/$DRIFT_BRANCH" > /dev/null || true
  exit 0
fi

: "${DRIFTED:?}" "${DRIFT_COUNT:?}" "${ERROR_COUNT:?}" "${RUN_URL:?}"
all=$(find "$results_dir" -name result.json -exec cat {} + | jq -s 'sort_by(.project)')
today=$(date -u +%F)
inventory=$(yq -r '.projects[].name' digger.yml)
allowed=$(for p in $DRIFTED; do grep -qx "${p%%(*}" <<<"$inventory" && printf '%s ' "${p%%(*}"; done)

{
  echo "# Infrastructure drift — $today"
  echo
  echo "**$DRIFT_COUNT drifted · $ERROR_COUNT error(s)** · [workflow run]($RUN_URL)"
  echo
  echo "Sticky PR maintained by the drift workflow. **Do not merge.** Reconcile with \`digger apply -p <project>\` from this PR, or fix the code on main."
  echo
  echo "| Project | Status | Summary |"
  echo "|---|---|---|"
  for p in $DRIFTED; do
    name=${p%%(*}
    row=$(jq -r --arg n "$name" '.[] | select(.project == $n) | "\(.summary)"' <<<"$all")
    case $p in *"(error)") echo "| \`$name\` | ❌ error | ${row:-no result} |" ;; *) echo "| \`$name\` | ⚠️ drift | $row |" ;; esac
  done
  echo
  jq -r '.[] | select(.result == "FAILED" or (.summary | test("^Plan: "))) |
    "<details><summary><code>\(.project)</code> — \(.summary)</summary>\n\n```hcl\n\(.output | .[-8000:])\n```\n</details>\n"' <<<"$all"
  echo
  echo "<!-- drift-allowed-projects: ${allowed% } -->"
} > "$REPORT"

git fetch "$remote" main --depth=1
git checkout -B "$DRIFT_BRANCH" FETCH_HEAD
git add "$REPORT"
git -c user.name="drift-bot" -c user.email="drift-bot@users.noreply.github.com" commit -m "chore(drift): snapshot $today" --no-verify
git push --force "$remote" "HEAD:refs/heads/$DRIFT_BRANCH"

title="[drift] Infrastructure drift detected — $today"
body=$(cat "$REPORT")
pr=$(find_pr)
if [ -n "$pr" ]; then
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/pulls/$pr" -f title="$title" -f body="$body" > /dev/null
else
  gh api -X POST "repos/$GITHUB_REPOSITORY/pulls" -f title="$title" -f body="$body" -f head="$DRIFT_BRANCH" -f base=main > /dev/null
fi
