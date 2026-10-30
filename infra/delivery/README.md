# Delivery

The delivery graph is defined once, in scripts, and driven by whichever CI
runs it. GitHub is the fixed point (source, PRs, Terraform CI); the app
delivery tool is a choice.

```
infra/delivery/
  config.yaml            registry, cloud identity, git bot, promotion rules
  lib/ci.sh              CI adapter: buildkite | github | local
  lib/cloud.sh           registry + identity adapter: ecr | gar | ghcr
  scripts/               the graph: affected → build → changelog → notify → promote
  buildkite/             Buildkite pipeline generator
.buildkite/pipeline.yml  Buildkite entry point
.github/workflows/delivery.yml   GitHub Actions implementation
```

| Concern | Buildkite | GitHub Actions |
| --- | --- | --- |
| affected apps | generator calls `affected-apps.sh` | `affected` job, matrix from its output |
| per-app approval | block step with `decision` and `backup` fields | `production` environment with required reviewers |
| who approved | `BUILDKITE_UNBLOCKER` | `github.triggering_actor` |
| stale approvals | `cancel-superseded-blocks.sh` | concurrency group on the promote job |
| run annotations | `buildkite-agent annotate` | job summary |
| cloud identity | agent OIDC token | `id-token: write` |

The tool's own configuration (pipeline, cluster, teams, or the GitHub
`production` environment) is Terraform: `infra/terraform/layers/deployment/buildkite`
and `infra/terraform/layers/foundations/github-org`.

The scripts call only `ci_*`, `cloud_*` and `registry_*` functions. To add
GitLab CI or another runner, implement the functions in `lib/ci.sh` and write
the pipeline file; the scripts do not change.

## Tags

| Branch | Tag | Repository |
| --- | --- | --- |
| default | `rel-<40-hex sha>` | `<app>` |
| PR | `pr-<app>-<sha>` | `preview_repo` |

The registry kind is config: ECR, Artifact Registry or GHCR. Image existence,
login and the prod keep-tag are implemented per kind in `lib/cloud.sh`.

## App contract

Any directory under `apps/` with a `Dockerfile` is an app, in any language.
The platform needs three things from it:

| File | Purpose |
| --- | --- |
| `Dockerfile` | how to build it; BuildKit secrets for private indexes (`npm_token`, `pip_index_url`) |
| `Makefile` with `test` and `lint` | how to check it; tools pinned in `apps/<app>/mise.toml` |
| `.platform/values*.yaml` | how to run it (port, health, resources, secrets, database) |

Optional: `deps.txt` (paths that should trigger a rebuild, for shared
packages) and `.platform/prebuild.sh` for steps a Dockerfile cannot do.
See `apps/README.md`.
