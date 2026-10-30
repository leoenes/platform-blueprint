#!/usr/bin/env bash
# Build and push apps/<app>:<tag>. Immutable tags: an existing tag skips the build.
set -euo pipefail
app=${1:?app} tag=${2:?tag}
cd "$(dirname "$0")/../../.."
. infra/delivery/lib/ci.sh
. infra/delivery/lib/cloud.sh

url=$(cfg .registry.url)
case $tag in
  pr-*) repo=$(cfg .registry.preview_repo); level=general ;;
  rel-*) repo=$app; level=prod ;;
  *) echo "unknown tag scheme $tag (pr-* or rel-*)" >&2; exit 1 ;;
esac

cloud_login "$level"
if registry_image_exists "$repo" "$tag"; then
  echo "$repo:$tag already exists; skipping immutable rebuild"
  ci_meta_set "image-uri:$app" "$url/$repo:$tag"
  exit 0
fi
registry_login

# Optional per-app hook before the build.
[ -x "apps/$app/.platform/prebuild.sh" ] && "apps/$app/.platform/prebuild.sh"

docker buildx build --push \
  --file "apps/$app/Dockerfile" \
  --tag "$url/$repo:$tag" \
  --cache-from "type=registry,ref=$url/$(cfg .registry.cache_repo):$app" \
  --cache-to "type=registry,ref=$url/$(cfg .registry.cache_repo):$app,mode=max" \
  --provenance=true --sbom=true \
  ${NPM_TOKEN:+--secret id=npm_token,env=NPM_TOKEN} \
  ${PIP_INDEX_URL:+--secret id=pip_index_url,env=PIP_INDEX_URL} \
  "apps/$app"

ci_meta_set "image-uri:$app" "$url/$repo:$tag"
