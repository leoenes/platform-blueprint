terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    github = { source = "integrations/github", version = "~> 6.6" }
  }
}

# Token comes from GITHUB_TOKEN in the environment (a GitHub App installation
# token minted by CI, or a fine-grained PAT locally). Never from a variable.
provider "github" {
  owner = var.github_owner
}
