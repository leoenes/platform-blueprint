variable "env" {
  type = string
}

variable "region" {
  description = "Hetzner location (nbg1, fsn1, hel1, ash, hil)"
  type        = string
}

variable "account_id" {
  type = string
}

variable "network_zone" {
  type    = string
  default = "eu-central"
}

variable "network_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "nodes_cidr" {
  type    = string
  default = "10.100.1.0/24"
}

variable "admin_cidrs" {
  type = list(string)
}

variable "control_type" {
  type    = string
  default = "cx22"
}

variable "worker_type" {
  type    = string
  default = "cx32"
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "ssh_key_ids" {
  type = list(string)
}

variable "k3s_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}
