# GitHub organization as code, driven by the same registry as everything else.
# Also the proof that the layer/instance convention is not AWS-specific: this
# layer has no AWS provider at all, only its state lives in S3.

module "access" {
  source       = "../../../modules/human_access"
  registry_dir = var.registry_dir
}

locals {
  members = { for h, p in module.access.catalog : h => p if p.access.github != null }
  team_memberships = merge([
    for h, p in local.members : { for t in p.access.github.teams : "${t}/${h}" => { team = t, handle = h } }
  ]...)
}

resource "github_membership" "member" {
  for_each = local.members
  username = each.value.identity_center_username
  role     = each.value.access.github.role
}

resource "github_team" "team" {
  for_each = toset(distinct(flatten([for h, p in local.members : p.access.github.teams])))
  name     = each.key
  privacy  = "closed"
}

resource "github_team_membership" "member" {
  for_each = local.team_memberships
  team_id  = github_team.team[each.value.team].id
  username = local.members[each.value.handle].identity_center_username
  role     = "member"
}

resource "github_repository" "platform" {
  name                   = "platform"
  visibility             = "private"
  delete_branch_on_merge = true
  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  vulnerability_alerts   = true
}

# Trunk-based: nothing lands on main without a PR, a review and green checks.
resource "github_branch_protection" "main" {
  repository_id          = github_repository.platform.node_id
  pattern                = "main"
  require_linear_history = true
  allows_force_pushes    = false

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  required_status_checks {
    strict   = true
    contexts = ["danger", "Terraform / inventory", "Terraform / aggregate"]
  }

  # The deploy bot pushes promotion commits directly (reviewed in the CD gate).
  push_restrictions = [var.deploy_app_node_id]
}

# The GitHub Actions prod gate, defined the same way the Buildkite one is
# (deployment/buildkite layer): who may approve is a registry team, not a
# setting someone clicked.
resource "github_repository_environment" "production" {
  repository          = github_repository.platform.name
  environment         = "production"
  prevent_self_review = true

  reviewers {
    teams = [for t in var.prod_reviewer_teams : github_team.team[t].id]
  }

  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
}
