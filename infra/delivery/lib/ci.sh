#!/usr/bin/env bash
# CI adapter: delivery scripts use only these functions, so they run under
# Buildkite, GitHub Actions or locally. Add a backend by implementing them.
#   ci_name ci_branch ci_sha ci_build_url ci_actor ci_approver
#   ci_meta_set k v · ci_meta_get k default · ci_annotate ctx style text
#   ci_oidc_token audience · ci_is_default_branch

set -euo pipefail
CFG=${DELIVERY_CONFIG:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config.yaml"}
cfg() { yq -r "$1" "$CFG"; }

if [ -n "${BUILDKITE:-}" ]; then
  ci_name() { echo buildkite; }
  ci_branch() { echo "$BUILDKITE_BRANCH"; }
  ci_sha() { echo "$BUILDKITE_COMMIT"; }
  ci_build_url() { echo "$BUILDKITE_BUILD_URL"; }
  ci_actor() { echo "${BUILDKITE_BUILD_CREATOR:-$BUILDKITE_BUILD_AUTHOR}"; }
  ci_approver() { echo "${BUILDKITE_UNBLOCKER:-}"; }
  ci_meta_set() { buildkite-agent meta-data set "$1" "$2"; }
  ci_meta_get() { buildkite-agent meta-data get "$1" --default "${2:-}"; }
  ci_annotate() { buildkite-agent annotate --context "$1" --style "$2" "$3"; }
  ci_oidc_token() { buildkite-agent oidc request-token --audience "$1" --aws-session-tag "organization_slug,pipeline_slug,build_branch,build_number"; }
elif [ -n "${GITHUB_ACTIONS:-}" ]; then
  ci_name() { echo github; }
  ci_branch() { echo "${GITHUB_HEAD_REF:-${GITHUB_REF_NAME}}"; }
  ci_sha() { echo "${PR_HEAD_SHA:-$GITHUB_SHA}"; }
  ci_build_url() { echo "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"; }
  ci_actor() { echo "$GITHUB_ACTOR"; }
  ci_approver() { echo "${DEPLOYMENT_APPROVER:-$GITHUB_ACTOR}"; }
  # Meta survives within a job; across jobs use artifacts.
  ci_meta_set() { echo "$1=$2" >> "$GITHUB_OUTPUT"; mkdir -p "${RUNNER_TEMP}/meta"; printf '%s' "$2" > "${RUNNER_TEMP}/meta/$1"; }
  ci_meta_get() { cat "${RUNNER_TEMP}/meta/$1" 2>/dev/null || echo "${2:-}"; }
  ci_annotate() { { echo "### $1 ($2)"; echo; echo "$3"; } >> "$GITHUB_STEP_SUMMARY"; }
  ci_oidc_token() { curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$1" | jq -r .value; }
else
  ci_name() { echo local; }
  ci_branch() { git rev-parse --abbrev-ref HEAD; }
  ci_sha() { git rev-parse HEAD; }
  ci_build_url() { echo "local"; }
  ci_actor() { git config user.name; }
  ci_approver() { git config user.name; }
  ci_meta_set() { mkdir -p /tmp/ci-meta; printf '%s' "$2" > "/tmp/ci-meta/$1"; }
  ci_meta_get() { cat "/tmp/ci-meta/$1" 2>/dev/null || echo "${2:-}"; }
  ci_annotate() { echo "[$1/$2] $3"; }
  ci_oidc_token() { echo "no OIDC outside CI; use local credentials" >&2; return 1; }
fi

ci_is_default_branch() { [ "$(ci_branch)" = "$(cfg .git.default_branch)" ]; }
