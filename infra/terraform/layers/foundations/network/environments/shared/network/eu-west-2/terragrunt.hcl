include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  flow_logs_bucket_arn = "arn:aws:s3:::acme-vpc-flow-logs-eu-west-2"

  workload_vpcs = {
    nonproduction = {
      account_id         = "111111111111"
      cidr               = "10.10.0.0/16"
      public_subnets     = ["10.10.0.0/22", "10.10.4.0/22", "10.10.8.0/22"]
      private_subnets    = ["10.10.32.0/20", "10.10.48.0/20", "10.10.64.0/20"]
      intra_subnets      = ["10.10.96.0/22", "10.10.100.0/22", "10.10.104.0/22"]
      single_nat_gateway = true
    }
    production = {
      account_id      = "333333333333"
      cidr            = "10.20.0.0/16"
      public_subnets  = ["10.20.0.0/22", "10.20.4.0/22", "10.20.8.0/22"]
      private_subnets = ["10.20.32.0/20", "10.20.48.0/20", "10.20.64.0/20"]
      intra_subnets   = ["10.20.96.0/22", "10.20.100.0/22", "10.20.104.0/22"]
    }
  }

  tags = { Env = "network", ManagedBy = "terraform" }
}
