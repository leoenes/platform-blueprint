# Terragrunt root. Every instance lives at
#   layers/<category>/<layer>/environments/<stage>/<leader>/<region>/terragrunt.hcl
# and only adds an `inputs = {}` block. Backend, cloud, account/project, role
# and lock timeout are derived from the path, so a new environment, region or
# even cloud is a new directory plus one entry in `envs` below.
#
# <leader> names the tenant inside a stage: a country for the primary cloud
# (uk, us), or <cloud>-<area> for others (gcp-eu, hetzner-eu), or a shared
# role (organization, network, deployment, security, github).

locals {
  parts    = split("/", path_relative_to_include())
  category = local.parts[1] # foundations | workloads | deployment
  layer    = local.parts[2] # network, eks, gke, ...
  stage    = local.parts[4] # nonprod | prod | shared
  leader   = local.parts[5]
  region   = local.parts[6] # provider region, or "global"

  # One entry per tenant. `cloud` picks the auth path; `state` picks the backend.
  envs = {
    # ── AWS: one account per blast radius ──────────────────────────────────
    "nonprod/uk"          = { cloud = "aws", id = "111111111111", state = { backend = "s3", bucket = "platform-111111111111-tfstate", region = "eu-west-2" } }
    "nonprod/us"          = { cloud = "aws", id = "222222222222", state = { backend = "s3", bucket = "platform-222222222222-tfstate", region = "us-east-1" } }
    "prod/uk"             = { cloud = "aws", id = "333333333333", state = { backend = "s3", bucket = "platform-333333333333-tfstate", region = "eu-west-2" } }
    "shared/organization" = { cloud = "aws", id = "444444444444", state = { backend = "s3", bucket = "platform-444444444444-tfstate", region = "eu-west-2" } }
    "shared/network"      = { cloud = "aws", id = "555555555555", state = { backend = "s3", bucket = "platform-555555555555-tfstate", region = "eu-west-2" } }
    "shared/deployment"   = { cloud = "aws", id = "666666666666", state = { backend = "s3", bucket = "platform-666666666666-tfstate", region = "eu-west-2" } }
    "shared/security"     = { cloud = "aws", id = "777777777777", state = { backend = "s3", bucket = "platform-777777777777-tfstate", region = "eu-west-2" } }

    # ── GCP: one project per stage+area, state in GCS ──────────────────────
    "nonprod/gcp-eu" = { cloud = "gcp", id = "acme-nonprod-eu", state = { backend = "gcs", bucket = "acme-nonprod-eu-tfstate" } }

    # ── Providers without a state service: state in the organization bucket ─
    "nonprod/hetzner-eu" = { cloud = "hetzner", id = "acme-hetzner", state = { backend = "s3", bucket = "platform-444444444444-tfstate", region = "eu-west-2" } }
    "shared/github"      = { cloud = "github", id = "acme", state = { backend = "s3", bucket = "platform-444444444444-tfstate", region = "eu-west-2" } }
  }

  env_key = "${local.stage}/${local.leader}"
  env     = local.envs[local.env_key]
  env_name = "acme-${replace(local.env_key, "/", "-")}"

  state_key = "${local.env_name}/${local.region}/${local.category}/${local.layer}/terraform.tfstate"

  # CI sets TG_CI_MODE=1. AWS: OIDC into the deployment account, then
  # chain-assume the per-account role. GCP: workload identity in the job,
  # nothing to assume here. Others: provider tokens in the environment.
  ci_mode = get_env("TG_CI_MODE", "") != ""

  aws_profile = local.env.cloud == "aws" && !local.ci_mode ? get_env("TG_PROVIDER_AWS_PROFILE", "${local.env_name}-administrator") : ""
  ci_iam_role = local.env.cloud == "aws" && local.ci_mode ? "arn:aws:iam::${local.env.id}:role/gh-actions-terraform" : ""

  backend_config = local.env.state.backend == "s3" ? {
    bucket         = local.env.state.bucket
    key            = local.state_key
    region         = local.env.state.region
    encrypt        = true
    dynamodb_table = "${local.env.state.bucket}-lock"
    } : {
    bucket = local.env.state.bucket
    prefix = local.state_key
  }
}

iam_role = local.ci_iam_role

remote_state {
  backend = local.env.state.backend
  config  = local.backend_config
}

inputs = {
  env        = local.env_name
  cloud      = local.env.cloud
  account_id = local.env.id # AWS account, GCP project, or org handle
  region     = local.region
  stage      = local.stage
  leader     = local.leader
  repo_root  = get_repo_root()
}

terraform {
  # `//` widens the copied tree to infra/terraform so ../../../modules/* refs
  # resolve inside .terragrunt-cache.
  source = "${get_repo_root()}/infra/terraform//layers/${local.category}/${local.layer}"

  extra_arguments "aws_profile" {
    commands = ["init", "plan", "apply", "validate", "refresh", "destroy", "import", "state", "output", "show"]
    env_vars = local.aws_profile != "" ? { AWS_PROFILE = local.aws_profile } : {}
  }

  # PR applies, the drift cron and ad-hoc local plans can overlap.
  # A long lock timeout makes them queue instead of fail.
  extra_arguments "lock_timeout" {
    commands  = ["plan", "apply", "destroy", "refresh", "import"]
    arguments = ["-lock-timeout=15m"]
  }
}

terraform_binary = "tofu"
