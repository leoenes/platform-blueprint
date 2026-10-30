# Subnets come from the network account through RAM; look them up by tag
# instead of wiring remote state across accounts.

data "aws_vpc" "shared" {
  filter {
    name   = "tag:Type"
    values = [var.vpc_tier]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

data "aws_iam_roles" "sso_admin" {
  name_regex  = var.sso_admin_role_regex
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

data "aws_iam_roles" "sso_viewer" {
  name_regex  = var.sso_viewer_role_regex
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  vpc_id             = data.aws_vpc.shared.id
  private_subnet_ids = data.aws_subnets.private.ids

  sso_admin_role_arns  = { for arn in data.aws_iam_roles.sso_admin.arns : basename(arn) => arn }
  sso_viewer_role_arns = { for arn in data.aws_iam_roles.sso_viewer.arns : basename(arn) => arn }
}
