variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "role_name" {
  type    = string
  default = "gh-actions-terraform"
}

variable "allowed_repos" {
  description = "GitHub repositories (owner/name) whose workflows may assume the role"
  type        = list(string)
}

variable "create_oidc_provider" {
  type    = bool
  default = true
}

variable "trusted_aws_principals" {
  description = "Role ARNs allowed to chain-assume this role (the bootstrap account's CI role)"
  type        = list(string)
  default     = []
}

variable "allowed_services" {
  description = "Service prefixes granted <service>:* to Terraform in this account"
  type        = list(string)
}

variable "allowed_actions" {
  description = "Extra fine-grained actions outside allowed_services"
  type        = list(string)
  default     = []
}

variable "permission_boundary_arn" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
