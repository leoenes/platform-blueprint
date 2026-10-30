# One-time per account, local credentials and local state (it creates the
# state bucket): tofu init && tofu apply -var-file=envs/<tenant>.tfvars

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
