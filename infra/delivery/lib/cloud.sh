#!/usr/bin/env bash
# Cloud adapter for the registry and identity. Source after ci.sh.
#
#   cloud_login <general|prod>   exchange the CI OIDC token for cloud creds
#   registry_login               docker login to the configured registry
#   registry_image_exists repo tag
#   registry_tag_image repo tag new_tag   (protect a prod image from lifecycle)
set -euo pipefail

cloud_login() {
  local level=${1:?general|prod}
  case "$(cfg .registry.kind)" in
    ecr)
      local role; role=$(cfg ".identity.aws.${level}_role")
      local token; token=$(ci_oidc_token sts.amazonaws.com)
      read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN < <(aws sts assume-role-with-web-identity \
        --role-arn "$role" --web-identity-token "$token" --role-session-name "ci-$(ci_name)" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN ;;
    gar)
      local token; token=$(ci_oidc_token "https://iam.googleapis.com/$(cfg .identity.gcp.workload_identity_provider)")
      printf '%s' "$token" > "${RUNNER_TEMP:-/tmp}/oidc.jwt"
      gcloud iam workload-identity-pools create-cred-config "$(cfg .identity.gcp.workload_identity_provider)" \
        --service-account="$(cfg ".identity.gcp.${level}_service_account")" \
        --credential-source-file="${RUNNER_TEMP:-/tmp}/oidc.jwt" --output-file="${RUNNER_TEMP:-/tmp}/gcp-creds.json"
      export GOOGLE_APPLICATION_CREDENTIALS="${RUNNER_TEMP:-/tmp}/gcp-creds.json" ;;
    ghcr) : ;; # GITHUB_TOKEN with packages:write is enough
    *) echo "unknown registry kind" >&2; return 1 ;;
  esac
}

registry_login() {
  local url; url=$(cfg .registry.url)
  case "$(cfg .registry.kind)" in
    ecr)  aws ecr get-login-password --region "$(cfg .registry.region)" | docker login --username AWS --password-stdin "$url" ;;
    gar)  gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "https://$url" ;;
    ghcr) printf '%s' "${GITHUB_TOKEN:?}" | docker login ghcr.io -u "$(ci_actor)" --password-stdin ;;
  esac
}

registry_image_exists() {
  local repo=$1 tag=$2
  case "$(cfg .registry.kind)" in
    ecr) aws ecr describe-images --region "$(cfg .registry.region)" --repository-name "$repo" --image-ids imageTag="$tag" >/dev/null 2>&1 ;;
    *)   docker manifest inspect "$(cfg .registry.url)/$repo:$tag" >/dev/null 2>&1 ;;
  esac
}

registry_tag_image() {
  local repo=$1 tag=$2 new=$3
  case "$(cfg .registry.kind)" in
    ecr)
      local m; m=$(aws ecr batch-get-image --region "$(cfg .registry.region)" --repository-name "$repo" --image-ids imageTag="$tag" --query 'images[0].imageManifest' --output text)
      aws ecr put-image --region "$(cfg .registry.region)" --repository-name "$repo" --image-tag "$new" --image-manifest "$m" >/dev/null ;;
    *) docker buildx imagetools create --tag "$(cfg .registry.url)/$repo:$new" "$(cfg .registry.url)/$repo:$tag" ;;
  esac
}
