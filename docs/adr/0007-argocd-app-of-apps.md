# 0007 — ArgoCD app-of-apps with a values-only app contract

**Context.** App teams should ship features, not Kubernetes YAML. Platform
tooling should be upgradable per cluster without Terraform.

**Decision.** Terraform installs ArgoCD, projects and two root apps. The
platform chart renders one Application per tool, disabled per cluster by a
list in the environment file. Apps declare `.platform/values*.yaml`; the
presence of a stage/region overlay is the deployment gate. ApplicationSets
discover apps from git.

**Consequences.**
- Adding a cluster tool or an app is YAML, reviewed in the same PR flow.
- Sync waves, `ServerSideApply` and `SkipDryRunOnMissingResource` are
  required for a fresh cluster to converge unattended.
- AppProjects bound namespaces per kind of workload, so an app cannot target
  another app's namespace.
