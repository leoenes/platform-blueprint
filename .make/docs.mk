# Docs site: MkDocs Material, pinned in docs/requirements.txt, published by
# .github/workflows/docs.yml. Local toolchain lives in a git-ignored venv.
DOCS_VENV := .venv-docs

.PHONY: docs-install docs-serve docs-build docs-check docs-lint-mermaid

$(DOCS_VENV)/bin/mkdocs: docs/requirements.txt
	python3 -m venv $(DOCS_VENV)
	$(DOCS_VENV)/bin/pip install -q -r docs/requirements.txt

docs-install: $(DOCS_VENV)/bin/mkdocs ## create .venv-docs with the pinned MkDocs toolchain

docs-serve: docs-install ## live-reload preview at http://127.0.0.1:8000/
	$(DOCS_VENV)/bin/mkdocs serve

docs-build: docs-install ## build the static site into ./site
	$(DOCS_VENV)/bin/mkdocs build --strict

docs-check: docs-install ## build in strict mode and discard (what CI runs)
	$(DOCS_VENV)/bin/mkdocs build --strict -d /tmp/platform-blueprint-site -q && rm -rf /tmp/platform-blueprint-site

docs-lint-mermaid: ## validate every Mermaid diagram in docs/ (downloads a headless browser on first run)
	.make/scripts/lint-mermaid.sh
