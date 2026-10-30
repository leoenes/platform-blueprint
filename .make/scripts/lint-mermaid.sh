#!/usr/bin/env bash
# Parse every ```mermaid block under docs/ with the Mermaid CLI. Catches the
# syntax errors the site and GitHub would otherwise render as a red banner.
set -euo pipefail
cd "$(dirname "$0")/../.."
MERMAID_CLI=${MERMAID_CLI:-@mermaid-js/mermaid-cli@11.12.0}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - "$tmp" <<'PY'
import glob, os, re, sys
out = sys.argv[1]
for f in sorted(glob.glob("docs/**/*.md", recursive=True)):
    blocks = re.findall(r"```mermaid\n(.*?)```", open(f).read(), re.S)
    for i, block in enumerate(blocks, 1):
        name = f"{f.replace('/', '_')[:-3]}__{i}.mmd"
        open(os.path.join(out, name), "w").write(block)
PY

rc=0; n=0
for f in "$tmp"/*.mmd; do
  n=$((n + 1))
  if ! npx -y -p "$MERMAID_CLI" mmdc -q -i "$f" -o "$f.svg" >"$f.log" 2>&1; then
    rc=1
    echo "FAIL $(basename "$f" .mmd)"
    grep -m1 -E 'Parse error|Error:' "$f.log" || true
  fi
done
[ $rc = 0 ] && echo "$n diagrams parse"
exit $rc
