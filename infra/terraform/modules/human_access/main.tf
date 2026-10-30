# Pure resolver (no providers): users.yaml + teams.yaml → catalog per person.

locals {
  users = yamldecode(file("${var.registry_dir}/users.yaml")).people
  teams = yamldecode(file("${var.registry_dir}/teams.yaml")).teams

  services = ["github", "buildkite", "vpn", "observability", "slack"]

  # Union of bundles across the person's teams.
  inherited = {
    for handle, u in local.users : handle => {
      for svc in local.services : svc => {
        role     = try(coalesce([for t in u.teams : try(local.teams[t].access[svc].role, null)]...), null)
        roles    = sort(distinct(flatten([for t in u.teams : try(local.teams[t].access[svc].roles, [])])))
        teams    = sort(distinct(flatten([for t in u.teams : try(local.teams[t].access[svc].teams, [])])))
        groups   = sort(distinct(flatten([for t in u.teams : try(local.teams[t].access[svc].groups, [])])))
        channels = sort(distinct(flatten([for t in u.teams : try(local.teams[t].access[svc].channels, [])])))
      }
    }
  }

  # User field replaces the bundle; `null` disables; Slack is additive.
  catalog = {
    for handle, u in local.users : handle => {
      identity_center_username = u.identityCenterUsername
      email                    = try(u.email, "${u.identityCenterUsername}@example.com")
      given_name               = u.givenName
      family_name              = u.familyName
      create_sso_user          = try(u.createSsoUser, false)
      teams                    = u.teams
      access = {
        for svc in local.services : svc => (
          contains(keys(try(u.access, {})), svc) && try(u.access[svc], null) == null ? null :
          svc == "slack" ? merge(local.inherited[handle][svc], {
            channels = sort(distinct(concat(local.inherited[handle][svc].channels, try(u.access[svc].channels, []))))
          }) :
          merge(local.inherited[handle][svc], try(u.access[svc], {}))
        )
      }
    }
  }
}

check "unknown_teams" {
  assert {
    condition     = alltrue([for h, u in local.users : alltrue([for t in u.teams : contains(keys(local.teams), t)])])
    error_message = "users.yaml references a team that does not exist in teams.yaml"
  }
}

check "unique_usernames" {
  assert {
    condition     = length(distinct([for h, u in local.users : u.identityCenterUsername])) == length(local.users)
    error_message = "identityCenterUsername must be unique"
  }
}

output "catalog" {
  value = local.catalog
}
