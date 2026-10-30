# Contributing

This is a reference repository, so most contributions are corrections,
clarifications or an additional option for one of the free choices (a cloud,
a CD tool, a language). Issues and PRs are welcome.

## Local checks

```sh
mise install   # pins every tool used by the checks
make check     # fmt, shellcheck, actionlint, helm lint/render, inventory, staging dry-run
```

```sh
make docs-serve   # live preview of the site at http://127.0.0.1:8000/
```

`make help` lists the rest; targets live in `.make/*.mk`, one file per concern. The published site is
https://leoenes.github.io/platform-blueprint/, rebuilt on every push to main.

## Conventions

- PR titles follow Conventional Commits (`feat(eks): …`, `docs: …`); Danger enforces it.
- Adding a layer or region: add the `terragrunt.hcl`, run `make inventory`, commit `digger.yml`.
- Adding a tool choice: keep the adapter thin and document it in `docs/09-portability.md`.
- A design decision gets a one-page ADR in `docs/adr/`.
- Nothing real: fictional org, placeholder IDs, example domains.
