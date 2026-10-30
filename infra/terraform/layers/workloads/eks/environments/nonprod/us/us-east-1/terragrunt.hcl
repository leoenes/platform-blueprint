include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  cluster_name    = "nonprod-us"
  cluster_version = "1.37"
  vpc_tier        = "nonproduction"

  tags = { Env = "nonprod-us", ManagedBy = "terraform" }
}
