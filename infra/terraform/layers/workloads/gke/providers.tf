terraform {
  required_version = ">= 1.10"
  backend "gcs" {}
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

# Credentials: Workload Identity Federation in CI (google-github-actions/auth),
# `gcloud auth application-default login` locally.
provider "google" {
  project = var.account_id
  region  = var.region
}
