terraform {
  required_version = ">= 1.10"
  backend "s3" {}
  required_providers {
    hcloud     = { source = "hetznercloud/hcloud", version = "~> 1.51" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.0" }
  }
}

# HCLOUD_TOKEN and CLOUDFLARE_API_TOKEN come from the environment, sourced
# from Secrets Manager by a provider-token helper in CI.
provider "hcloud" {}
provider "cloudflare" {}
