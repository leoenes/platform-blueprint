# AppProjects are the namespace boundary: an app cannot be told to deploy
# into another app's namespace by editing its own values.
locals {
  projects = {
    platform = { namespaces = ["*"], description = "cluster tooling" }
    apps     = { namespaces = ["app-*"], description = "application workloads" }
    preview  = { namespaces = ["preview-*"], description = "PR preview environments" }
  }
}

resource "kubectl_manifest" "projects" {
  for_each = local.projects
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata   = { name = each.key, namespace = "argocd" }
    spec = {
      description                = each.value.description
      sourceRepos                = ["*"]
      destinations               = [for ns in each.value.namespaces : { server = "https://kubernetes.default.svc", namespace = ns }]
      clusterResourceWhitelist   = each.key == "platform" ? [{ group = "*", kind = "*" }] : []
      namespaceResourceBlacklist = each.key == "platform" ? [] : [{ group = "", kind = "ResourceQuota" }, { group = "", kind = "LimitRange" }]
    }
  })
  depends_on = [helm_release.argocd]
}
