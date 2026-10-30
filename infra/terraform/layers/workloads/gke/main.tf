# GKE Autopilot: GCP counterpart of the eks layer, same instance convention.

resource "google_compute_network" "this" {
  name                    = "${var.env}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.env}-nodes"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.nodes_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.region
  project  = var.account_id

  enable_autopilot    = true
  deletion_protection = var.stage == "prod"
  network             = google_compute_network.this.id
  subnetwork          = google_compute_subnetwork.nodes.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  release_channel {
    channel = var.stage == "prod" ? "STABLE" : "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.account_id}.svc.id.goog"
  }
}

# Workload Identity for External Secrets (the EKS Pod Identity equivalent).
resource "google_service_account" "external_secrets" {
  account_id   = "${var.cluster_name}-eso"
  display_name = "External Secrets for ${var.cluster_name}"
}

resource "google_project_iam_member" "external_secrets" {
  project = var.account_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

resource "google_service_account_iam_member" "external_secrets_wi" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.account_id}.svc.id.goog[external-secrets/external-secrets]"
}
