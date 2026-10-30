#!/usr/bin/env bash
# Buildkite pipeline for this commit, calling infra/delivery/scripts.
# PR: test → preview build (label preview-<app>). main: test → push → changelog
# → notify → block per app → promote.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. infra/delivery/lib/ci.sh

if ci_is_default_branch; then base='HEAD^'; else base="origin/${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-main}"; fi
mapfile -t apps < <(infra/delivery/scripts/affected-apps.sh "$base")
if [ ${#apps[@]} -eq 0 ]; then echo 'steps: [{label: "nothing to build", command: "true"}]'; exit 0; fi

emit() { printf '%s\n' "$@"; }
emit "steps:"
for app in "${apps[@]}"; do
  emit "  - label: \":test_tube: $app\"" \
       "    key: test-$app" \
       "    command: make -C apps/$app test lint"
done
emit "  - wait"

if ! ci_is_default_branch; then
  for app in "${apps[@]}"; do
    emit "  - label: \":docker: preview $app\"" \
         "    if: build.pull_request.labels includes \"preview-$app\"" \
         "    command: infra/delivery/scripts/build-and-push-app.sh $app pr-$app-\$BUILDKITE_COMMIT && infra/delivery/scripts/preview-comment.sh $app"
  done
  exit 0
fi

for app in "${apps[@]}"; do
  emit "  - label: \":docker: push $app\"" \
       "    key: push-$app" \
       "    concurrency: 1" \
       "    concurrency_group: registry-push-$app" \
       "    command: infra/delivery/scripts/build-and-push-app.sh $app rel-\$BUILDKITE_COMMIT" \
       "  - label: \":memo: changelog $app\"" \
       "    depends_on: push-$app" \
       "    command: infra/delivery/scripts/render-changelog.sh $app | buildkite-agent annotate --style info --context changelog-$app"
done
emit "  - wait"
emit "  - label: \":slack: promotions ready\"" \
     "    key: promotions-ready-notify" \
     "    soft_fail: true" \
     "    command: infra/delivery/scripts/slack-notify.sh promotions-ready ${apps[*]}"

# Blocks depend on notify, not on each other: approvals are independent.
teams=$(cfg '.promotion.allowed_teams | join(", ")')
for app in "${apps[@]}"; do
  compgen -G "apps/$app/$(cfg .promotion.prod_overlay_glob)" >/dev/null || continue # no prod overlay = no prod
  emit "  - block: \":rocket: promote $app to prod\"" \
       "    key: block-$app" \
       "    depends_on: promotions-ready-notify" \
       "    allowed_teams: [$teams]" \
       "    fields:" \
       "      - select: decision" \
       "        key: decision-$app" \
       "        options: [{label: approve, value: approve}, {label: reject, value: reject}]" \
       "      - select: backup" \
       "        key: backup-$app" \
       "        hint: take an on-demand database recovery point before rollout" \
       "        options: [{label: take, value: take}, {label: skip, value: skip}]" \
       "  - label: \":rocket: promote $app\"" \
       "    depends_on: block-$app" \
       "    concurrency: 1" \
       "    concurrency_group: platform/prod-promote" \
       "    command: infra/delivery/scripts/promote-to-prod.sh $app rel-\$BUILDKITE_COMMIT"
done
