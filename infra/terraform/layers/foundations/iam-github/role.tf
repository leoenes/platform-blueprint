# CI role for Terraform in this account. Trusted by GitHub OIDC and,
# optionally, by the deployment account's role (chain-assume). Permissions
# are an allow-list, never AdministratorAccess.

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for r in var.allowed_repos : "repo:${r}:*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.trusted_aws_principals) > 0 ? [1] : []
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = var.trusted_aws_principals
      }
    }
  }
}

resource "aws_iam_role" "gh_actions_terraform" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.permission_boundary_arn != "" ? var.permission_boundary_arn : null
  tags                 = var.tags
}

data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "AllowedServices"
    effect    = "Allow"
    actions   = [for s in var.allowed_services : "${s}:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.allowed_actions) > 0 ? [1] : []
    content {
      sid       = "AllowedActions"
      effect    = "Allow"
      actions   = var.allowed_actions
      resources = ["*"]
    }
  }

  statement {
    sid    = "DenyDangerous"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:DeleteRolePermissionsBoundary",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "permissions" {
  name   = "${var.role_name}-permissions"
  role   = aws_iam_role.gh_actions_terraform.id
  policy = data.aws_iam_policy_document.permissions.json
}
