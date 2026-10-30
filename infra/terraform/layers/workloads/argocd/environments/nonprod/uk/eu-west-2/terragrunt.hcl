include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  cluster_name = "nonprod-uk"
  base_domain  = "uk.nonprod.example.com"
}
