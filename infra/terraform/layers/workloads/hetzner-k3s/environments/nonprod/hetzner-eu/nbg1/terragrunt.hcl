include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  admin_cidrs        = ["203.0.113.0/24"]
  ssh_key_ids        = ["12345678"]
  k3s_token          = get_env("K3S_TOKEN", "")
  cloudflare_zone_id = "0000000000000000000000000000000a"
  worker_count       = 2
}
