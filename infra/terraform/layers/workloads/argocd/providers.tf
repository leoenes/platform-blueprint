terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    helm    = { source = "hashicorp/helm", version = "~> 3.0" }
    kubectl = { source = "alekc/kubectl", version = "~> 2.1" }
    sops    = { source = "carlpett/sops", version = "~> 1.2" }
  }
}

provider "aws" {
  region = var.region
}
