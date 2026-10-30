include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  cluster_name    = "prod-uk"
  cluster_version = "1.36" # upgrades go one minor at a time, nonprod first
  vpc_tier        = "production"

  node_pools = {
    system = {
      instance_type = "m6i.large"
      min_size      = 2
      max_size      = 6
      desired_size  = 3
    }
  }

  tags = { Env = "prod-uk", ManagedBy = "terraform" }
}
