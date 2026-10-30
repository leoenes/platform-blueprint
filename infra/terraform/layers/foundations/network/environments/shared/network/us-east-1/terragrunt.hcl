include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Second region: same layer, different inputs. Non-overlapping CIDRs are the
# only cross-region coupling; the TGW peering closes the loop.
inputs = {
  flow_logs_bucket_arn = "arn:aws:s3:::acme-vpc-flow-logs-us-east-1"

  workload_vpcs = {
    nonproduction = {
      account_id         = "222222222222"
      cidr               = "10.30.0.0/16"
      public_subnets     = ["10.30.0.0/22", "10.30.4.0/22", "10.30.8.0/22"]
      private_subnets    = ["10.30.32.0/20", "10.30.48.0/20", "10.30.64.0/20"]
      intra_subnets      = ["10.30.96.0/22", "10.30.100.0/22", "10.30.104.0/22"]
      single_nat_gateway = true
    }
  }

  peer_tgw_id = "tgw-0eu-west-2-hub"
  peer_region = "eu-west-2"

  tags = { Env = "network", ManagedBy = "terraform" }
}
