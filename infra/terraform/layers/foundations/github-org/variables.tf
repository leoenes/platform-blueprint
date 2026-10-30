variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "registry_dir" {
  type = string
}

variable "github_owner" {
  type    = string
  default = "acme"
}

variable "prod_reviewer_teams" {
  description = "Registry teams whose members may approve the production environment"
  type        = list(string)
  default     = ["platform", "release-managers"]
}

variable "deploy_app_node_id" {
  description = "Node ID of the deploy GitHub App, allowed to push promotion commits to main"
  type        = string
}
