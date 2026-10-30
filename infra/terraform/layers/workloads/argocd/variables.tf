variable "env" {
  type = string
}

variable "stage" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "repo_url" {
  type    = string
  default = "https://github.com/acme/platform.git"
}

variable "chart_version" {
  type    = string
  default = "8.5.5"
}
