# Apps

The platform is language-agnostic by contract, not by accident. Each app is a
directory with a `Dockerfile`, a `Makefile` exposing `test` and `lint`, and a
`.platform/` directory describing how it runs. The build, preview, promotion
and GitOps layers never look inside the code.

| App | Language | Shows |
| --- | --- | --- |
| `example-api` | Go | HTTP service, blue/green rollout, database with extensions |
| `example-worker` | Python | queue consumer, no ingress, plain Deployment |

Adding an app in another language (TypeScript, Elixir, Rust, JVM) is the same
three files. Toolchains are pinned per app in `mise.toml`, so CI does not
carry a global language setup.

```
apps/<name>/
  Dockerfile                multi-stage, distroless or slim runtime
  Makefile                  test, lint (build is the Dockerfile's job)
  mise.toml                 language toolchain pins
  deps.txt                  optional: shared paths that trigger a rebuild
  .platform/
    values.yaml             base deployment contract
    values-<stage>-<region>.yaml   overlay and deployment gate
    preview.yaml            PR preview overlay
    prebuild.sh             optional hook before docker build
```
