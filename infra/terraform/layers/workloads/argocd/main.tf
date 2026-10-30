# Terraform installs ArgoCD and the root apps; after that, git owns the cluster.
# This is the only layer that talks to Kubernetes.

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

# Bootstrap-only secrets (repo token, OIDC client) are SOPS-encrypted in git.
# Everything after bootstrap goes through External Secrets.
data "sops_file" "bootstrap" {
  source_file = "${path.module}/secrets/${var.env}-${var.region}.enc.yaml"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version

  values = [templatefile("${path.module}/values/argocd.yaml.tftpl", {
    base_domain = var.base_domain
    oidc_client = data.sops_file.bootstrap.data["oidc_client_id"]
  })]
}

resource "kubectl_manifest" "repo_credentials" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "repo-platform", namespace = "argocd", labels = { "argocd.argoproj.io/secret-type" = "repository" } }
    stringData = { url = var.repo_url, username = "x-access-token", password = data.sops_file.bootstrap.data["repo_token"] }
  })
  depends_on = [helm_release.argocd]
}

# Root app: renders platform-apps (cluster tools *and* the ApplicationSets)
# with this cluster's environment file. Everything the cluster runs descends
# from this one Application.
# SkipDryRunOnMissingResource: the chart creates the child Apps that install
# CRDs *and* CRs that use them; without it the first sync fails dry-run.
resource "kubectl_manifest" "platform_root" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = { name = "platform-${local.env_short}", namespace = "argocd" }
    spec = {
      project = "platform"
      sources = [
        { repoURL = var.repo_url, targetRevision = "main", ref = "repo" },
        {
          repoURL = var.repo_url, targetRevision = "main", path = "infra/helm-charts/platform-apps"
          helm    = { valueFiles = ["$repo/infra/platform-config/environments/${local.env_short}.yaml"] }
        },
      ]
      destination = { server = "https://kubernetes.default.svc", namespace = "argocd" }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true", "ServerSideApply=true", "SkipDryRunOnMissingResource=true"]
        retry       = { limit = 20, backoff = { duration = "30s", factor = 2, maxDuration = "5m" } }
      }
    }
  })
  depends_on = [kubectl_manifest.projects]
}

locals {
  env_short = "${var.stage}-${var.region}"
}
