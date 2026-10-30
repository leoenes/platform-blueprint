include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  # Absolute path so file() works from inside .terragrunt-cache.
  registry_dir       = "${get_repo_root()}/infra/access"
  deploy_app_node_id = "BOT_kgDOAAAAAA"
}
