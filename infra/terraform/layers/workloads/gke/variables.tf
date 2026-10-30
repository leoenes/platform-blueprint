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
  description = "GCP project id (passed as account_id by root.hcl)"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "nodes_cidr" {
  type    = string
  default = "10.40.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.41.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.42.0.0/20"
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}
