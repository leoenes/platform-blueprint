variable "env" {
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

variable "cluster_version" {
  type    = string
  default = "1.35"
}

variable "vpc_tier" {
  description = "Type tag of the shared VPC to use (nonproduction | production)"
  type        = string
}

variable "endpoint_public_access" {
  type    = bool
  default = false
}

variable "node_pools" {
  description = "Managed node groups. Set desired_size=0 to disable a pool."
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
    labels        = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = string
      effect = string
    })), {})
  }))
  default = {
    system = {
      instance_type = "t3.medium"
      min_size      = 0
      max_size      = 3
      desired_size  = 2
    }
  }
}

variable "sso_admin_role_regex" {
  type    = string
  default = "AWSReservedSSO_AdministratorAccess_.*"
}

variable "sso_viewer_role_regex" {
  type    = string
  default = "AWSReservedSSO_ReadOnlyAccess_.*"
}

variable "tags" {
  type    = map(string)
  default = {}
}
