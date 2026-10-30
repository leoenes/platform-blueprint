# GitOps with ArgoCD

## Bootstrap once, then git

The `argocd` Terraform layer installs ArgoCD, the AppProjects and two root
Applications. After that nothing in a cluster is created by anything but
ArgoCD reading this repository.

| Root app | Source | Creates |
| --- | --- | --- |
| `platform-<env>` | `infra/helm-charts/platform-apps` + `environments/<stage>-<region>.yaml` | one child Application per cluster tool, plus the cluster's ApplicationSets |

One root, one values file per cluster. The ApplicationSets are chart
templates rendered from `global.stage` and `global.region`, so no file in the
repository lists regions. Adding a cluster tool is a template in the chart;
adding a cluster is one environment file. Neither needs Terraform beyond the
cluster itself.

## The app contract

An app owns a `.platform/` directory and nothing else about its deployment:

| File | Meaning |
| --- | --- |
| `values.yaml` | base: image, port, resources, autoscaling, secrets *names*, database |
| `values-<stage>-<region>.yaml` | overlay **and deployment gate**: no file, no Application |
| `preview.yaml` | overlay for PR previews |

Values merge in this order: cluster globals → app base → stage/region
overlay → preview overlay → `image.tag` parameter. The shared service chart
turns this into a Rollout or Deployment, Service, IngressRoute,
ExternalSecrets, PDB and KEDA ScaledObject.

## ApplicationSets

Both are rendered by `templates/appset-apps.yaml` from the cluster's own
stage and region.

**Nonprod**: git files generator over `apps/*/.platform/values-<stage>-<region>.yaml`.
Image Updater annotations select `^rel-[0-9a-f]{40}$`, newest build.
`ignoreApplicationDifferences` on the Helm parameters, otherwise the AppSet
controller would overwrite what Image Updater wrote.

**Prod**: same generator, but `targetRevision` is the SHA inside the promoted
tag. An invalid tag renders `invalid-prod-image-tag`, which does not exist,
so the Application fails to sync instead of deploying something unexpected.

**Preview**: matrix of a pull-request generator and a git files generator at
the PR's head SHA, rendered only where the environment file sets
`preview.enabled`. The cluster marked `preview.default` answers to the label
`preview-<app>`; any other cluster answers to `preview-<app>@<region>`.
`allowEmpty: true` so zero previews is a valid state.

## Platform-apps chart

Each template is an ArgoCD Application wrapped in
`{{ if include "platform.enabled" (list "<tool>" .Values) }}`, so a cluster
disables a tool by listing it in `disabledTools` in its environment file
(prod disables Image Updater). Sync waves order the install:

| Wave | What |
| --- | --- |
| -1 | operators and CRDs: External Secrets, cert-manager, Karpenter, Rollouts |
| 0 | ClusterSecretStore, storage classes |
| 1 | Karpenter NodePool and EC2NodeClass |
| 2+ | Traefik, metrics, observability, cron jobs |

The root app uses `ServerSideApply` and `SkipDryRunOnMissingResource`:
the same chart creates the Application that installs a CRD and a resource
of that CRD, and without the skip the first sync fails dry-run.

## Secrets

- Runtime: External Secrets Operator with a per-region ClusterSecretStore to
  AWS Secrets Manager. Apps declare `{key, property}`; the value never
  appears in git or in a plan.
- Bootstrap: the repository token and the SSO client, SOPS-encrypted with a
  per-account KMS key, decrypted by the argocd layer at apply. No laptop key
  is a creation rule.

## Small decisions that mattered

- `managedNamespaceMetadata` on the Traefik namespace enables ALB readiness
  gates, so a pod is Ready only when the ALB says so.
- `ignoreDifferences` on `/spec/replicas` (autoscalers own it) and on
  Rollout `restartAt`/`paused` (operators and restarters own them).
- Job names include the image tag; Jobs are immutable, so a new tag is a
  new Job.
