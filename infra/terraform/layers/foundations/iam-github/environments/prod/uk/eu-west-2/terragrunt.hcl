include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  allowed_repos = ["acme/platform"]

  # The eks layer owns the OIDC provider in workload accounts.
  create_oidc_provider = false

  # The deployment account's CI role is the single OIDC entry point;
  # it chain-assumes into this account (see root.hcl ci_iam_role).
  trusted_aws_principals = ["arn:aws:iam::666666666666:role/gh-actions-terraform"]

  allowed_services = [
    "acm", "autoscaling", "cloudwatch", "dynamodb", "ec2", "eks",
    "elasticloadbalancing", "events", "iam", "kms", "logs", "rds",
    "route53", "s3", "secretsmanager", "sns", "sqs", "ssm", "sts", "tag", "wafv2",
  ]

  tags = { Env = "prod-uk", ManagedBy = "terraform" }
}
