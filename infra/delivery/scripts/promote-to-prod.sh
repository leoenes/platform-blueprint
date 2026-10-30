#!/usr/bin/env bash
# Promote <app>: commit image.tag to main; ArgoCD prod renders at that SHA.
# Regression guard keeps prod monotonic. CI-agnostic via lib/ci.sh.
set -euo pipefail
app=${1:?app} tag=${2:?rel-<sha>}
cd "$(dirname "$0")/../../.."
. infra/delivery/lib/ci.sh
. infra/delivery/lib/cloud.sh

decision=$(ci_meta_get "decision-$app" approve)
backup=$(ci_meta_get "backup-$app" skip)
if [ "$decision" = reject ]; then
  ci_annotate "promote-$app" warning "Promotion of $app rejected by $(ci_approver)."
  infra/delivery/scripts/slack-notify.sh prod-rejected "$app"
  exit 0
fi

new_sha=${tag#rel-}
mapfile -t overlays < <(compgen -G "apps/$app/$(cfg .promotion.prod_overlay_glob)")
guard() {
  local current
  current=$(yq -r '.image.tag // ""' "${overlays[0]}")
  [ -n "$current" ] || return 0
  if git merge-base --is-ancestor "$new_sha" "${current#rel-}"; then
    echo "prod is already at or ahead of $new_sha ($current); nothing to do"; exit 0
  fi
}

git fetch origin "$(cfg .git.default_branch)"
guard
cloud_login prod

if [ "$backup" = take ]; then
  infra/delivery/scripts/pre-deploy-backup.sh "$app"
  guard # the backup can take a while; re-check that nobody promoted meanwhile
fi

# Token minted after the backup so it cannot expire mid-run.
token=$(infra/delivery/scripts/github-app-token.sh deploy)
git checkout -B promote "origin/$(cfg .git.default_branch)"
for f in "${overlays[@]}"; do yq -i ".image.tag = \"$tag\"" "$f"; done
changelog=$(infra/delivery/scripts/render-changelog.sh "$app")
git -c user.name="$(cfg .git.deploy_bot.name)" -c user.email="$(cfg .git.deploy_bot.email)" commit -am \
"deploy($app): promote ${new_sha:0:12} to prod [skip ci]

$changelog

Approved-by: $(ci_approver)
Build: $(ci_build_url)"
git push "https://x-access-token:${token}@github.com/$(cfg .git.repo).git" "HEAD:$(cfg .git.default_branch)"

# Protect the prod image from registry lifecycle expiry.
registry_tag_image "$app" "$tag" "keep-prod-$new_sha" || true

ci_annotate "promote-$app" success "Promoted $app to $tag. ArgoCD prod will sync at $new_sha."
infra/delivery/scripts/slack-notify.sh prod-committed "$app"
if [ "$(ci_name)" = buildkite ]; then infra/delivery/scripts/cancel-superseded-blocks.sh "$app" "$new_sha" || true; fi
