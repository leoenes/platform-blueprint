output "role_arn" {
  value = aws_iam_role.gh_actions_terraform.arn
}

output "oidc_provider_arn" {
  value = local.github_oidc_provider_arn
}
