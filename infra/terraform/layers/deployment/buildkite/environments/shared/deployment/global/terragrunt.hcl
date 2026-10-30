include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  registry_dir = "${get_repo_root()}/infra/access"
}
