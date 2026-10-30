# k3s on Hetzner with Cloudflare DNS. Same path convention and PR workflow; different providers.

resource "hcloud_network" "this" {
  name     = "${var.env}-${var.region}"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.nodes_cidr
}

resource "hcloud_firewall" "nodes" {
  name = "${var.env}-nodes"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_cidrs
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.admin_cidrs
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "control" {
  name         = "${var.env}-control-1"
  server_type  = var.control_type
  image        = "ubuntu-24.04"
  location     = var.region
  ssh_keys     = var.ssh_key_ids
  firewall_ids = [hcloud_firewall.nodes.id]
  user_data    = templatefile("${path.module}/cloud-init/control.yaml.tftpl", { k3s_token = var.k3s_token })

  network {
    network_id = hcloud_network.this.id
  }
  depends_on = [hcloud_network_subnet.nodes]
}

resource "hcloud_server" "worker" {
  count        = var.worker_count
  name         = "${var.env}-worker-${count.index + 1}"
  server_type  = var.worker_type
  image        = "ubuntu-24.04"
  location     = var.region
  ssh_keys     = var.ssh_key_ids
  firewall_ids = [hcloud_firewall.nodes.id]
  user_data = templatefile("${path.module}/cloud-init/worker.yaml.tftpl", {
    k3s_token  = var.k3s_token
    server_url = "https://${hcloud_server.control.network[*].ip[0]}:6443"
  })

  network {
    network_id = hcloud_network.this.id
  }
  depends_on = [hcloud_network_subnet.nodes]
}

resource "cloudflare_dns_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api.${var.env}"
  type    = "A"
  content = hcloud_server.control.ipv4_address
  proxied = true
  ttl     = 1
}
