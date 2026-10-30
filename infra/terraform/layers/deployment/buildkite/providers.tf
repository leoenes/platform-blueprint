terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    buildkite = { source = "buildkite/buildkite", version = "~> 1.21" }
  }
}

# BUILDKITE_API_TOKEN comes from the environment: read from the secrets
# store by the stage workflow in CI, exported by hand locally.
provider "buildkite" {
  organization = var.organization_slug
}
