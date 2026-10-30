include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  cluster_name    = "nonprod-uk"
  cluster_version = "1.37"
  vpc_tier        = "nonproduction"

  node_pools = {
    system = {
      instance_type = "t3.large"
      min_size      = 0
      max_size      = 4
      desired_size  = 2
    }
  }

  tags = { Env = "nonprod-uk", ManagedBy = "terraform" }
}
