#!/usr/bin/env bash
# Commits from the prod SHA to HEAD, scoped to the app and its deps. Never fails.
set -uo pipefail
app=${1:?}
trap 'exit 0' ERR
cd "$(dirname "$0")/../../.."
. infra/delivery/lib/ci.sh

overlay=$(compgen -G "apps/$app/$(cfg .promotion.prod_overlay_glob)" | head -1)
current=$(yq -r '.image.tag // ""' "$overlay" 2>/dev/null)
from=${current#rel-}
paths=("apps/$app")
[ -f "apps/$app/deps.txt" ] && mapfile -t -O 1 paths < "apps/$app/deps.txt"

echo "### $app — changes since ${from:0:7}"
if [ -n "$from" ] && git cat-file -e "$from" 2>/dev/null; then
  git log --no-merges --format='- %s (%h, %an)' "$from..HEAD" -- "${paths[@]}"
else
  echo "- first promotion"
fi
