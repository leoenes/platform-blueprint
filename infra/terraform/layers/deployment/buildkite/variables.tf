variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "organization_slug" {
  type    = string
  default = "acme"
}

variable "github_repo" {
  type    = string
  default = "acme/platform"
}

variable "registry_dir" {
  description = "Absolute path to infra/access"
  type        = string
}

variable "admin_teams" {
  description = "Registry teams that may manage the pipeline (and unblock prod)"
  type        = list(string)
  default     = ["platform", "release-managers"]
}
