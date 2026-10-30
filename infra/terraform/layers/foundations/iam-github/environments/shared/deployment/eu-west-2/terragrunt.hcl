include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Bootstrap account: the only place GitHub's OIDC token is exchanged.
inputs = {
  allowed_repos        = ["acme/platform"]
  create_oidc_provider = true

  allowed_services = ["ecr", "iam", "kms", "logs", "s3", "sts", "tag"]

  tags = { Env = "deployment", ManagedBy = "terraform" }
}
