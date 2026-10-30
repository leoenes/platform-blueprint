# One-time bootstrap per AWS account. Run with local admin credentials:
#   cd infra/terraform/setup
#   tofu init && tofu apply -var-file=envs/acme-nonprod-uk.tfvars
# The state of this root itself is local on purpose: it creates the bucket
# that every other layer stores state in.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_caller_identity" "current" {}

module "state" {
  source  = "../modules/bootstrap"
  project = "platform-${data.aws_caller_identity.current.account_id}"
}

output "state_bucket" {
  value = module.state.state_bucket
}

variable "region" {
  type = string
}

variable "profile" {
  type    = string
  default = null
}
