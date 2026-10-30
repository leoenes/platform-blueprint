variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "org" {
  type    = string
  default = "acme"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "workload_vpcs" {
  description = "VPCs owned by this network account, keyed by workload tier"
  type = map(object({
    account_id         = string
    cidr               = string
    public_subnets     = list(string)
    private_subnets    = list(string)
    intra_subnets      = list(string)
    single_nat_gateway = optional(bool, false)
  }))
}

variable "flow_logs_bucket_arn" {
  type = string
}

variable "peer_tgw_id" {
  type    = string
  default = ""
}

variable "peer_region" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
