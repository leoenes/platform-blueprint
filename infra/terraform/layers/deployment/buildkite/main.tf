# Buildkite as code: cluster, queue, token, pipeline definition, teams from
# the access registry. Steps stay dynamic (infra/delivery/buildkite).

module "access" {
  source       = "../../../modules/human_access"
  registry_dir = var.registry_dir
}

resource "buildkite_cluster" "platform" {
  name        = "platform"
  description = "Hosted agents for the platform monorepo"
}

resource "buildkite_cluster_queue" "default" {
  cluster_id  = buildkite_cluster.platform.id
  key         = "default"
  description = "general builds"
  hosted_agents = {
    instance_shape = "LINUX_AMD64_4X16"
  }
}

resource "buildkite_cluster_agent_token" "github_hosted" {
  cluster_id  = buildkite_cluster.platform.id
  description = "self-hosted agents in the deployment account"
}

resource "buildkite_pipeline" "platform" {
  name           = "platform"
  repository     = "git@github.com:${var.github_repo}.git"
  cluster_id     = buildkite_cluster.platform.id
  default_branch = "main"
  description    = "Trunk-based delivery: test, build, promote"

  # Static entry step only; it uploads the generated steps.
  steps = file("${path.module}/files/entry-steps.yml")

  provider_settings = {
    trigger_mode                     = "code"
    build_pull_requests              = true
    build_branches                   = true
    filter_enabled                   = true
    filter_condition                 = "build.branch == \"main\" || build.pull_request.id != null"
    publish_commit_status            = true
    publish_commit_status_per_step   = false
    cancel_deleted_branch_builds     = true
    skip_builds_for_existing_commits = true
  }

  tags = ["platform", "trunk-based"]
}

# No invite API: a person is reconciled into teams once their invite is accepted.
data "buildkite_organization_members" "all" {}

locals {
  user_ids = { for m in data.buildkite_organization_members.all.members : m.email => m.id }
  members  = { for h, p in module.access.catalog : h => p if p.access.buildkite != null && contains(keys(local.user_ids), p.email) }
  teams    = toset(distinct(flatten([for h, p in local.members : try(p.access.buildkite.teams, [])])))
  team_memberships = merge([
    for h, p in local.members : { for t in try(p.access.buildkite.teams, []) : "${t}/${h}" => { team = t, handle = h } }
  ]...)
  pending_invites = [for h, p in module.access.catalog : p.email if p.access.buildkite != null && !contains(keys(local.user_ids), p.email)]
}

resource "buildkite_team" "team" {
  for_each = local.teams

  name                         = each.key
  privacy                      = "VISIBLE"
  default_team                 = false
  default_member_role          = "MEMBER"
  members_can_create_pipelines = false
}

resource "buildkite_team_member" "member" {
  for_each = local.team_memberships
  team_id  = buildkite_team.team[each.value.team].id
  user_id  = local.user_ids[local.members[each.value.handle].email]
  role     = "MEMBER"
}

# Shown in every plan: who still has to accept the invite.
output "pending_invites" {
  value = local.pending_invites
}

resource "buildkite_pipeline_team" "platform" {
  for_each     = local.teams
  pipeline_id  = buildkite_pipeline.platform.id
  team_id      = buildkite_team.team[each.key].id
  access_level = contains(var.admin_teams, each.key) ? "MANAGE_BUILD_AND_READ" : "BUILD_AND_READ"
}

# Pinned by the ci-general / ci-prod trust policies in the iam-github layer.
output "oidc_claims" {
  value = {
    organization_slug = var.organization_slug
    pipeline_slug     = buildkite_pipeline.platform.slug
    cluster_id        = buildkite_cluster.platform.uuid
  }
}
