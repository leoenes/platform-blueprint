# Static analysis of scripts and workflows.
.PHONY: lint-shell lint-actions

lint-shell: ## shellcheck every script
	shellcheck -x $(SH)

lint-actions: ## actionlint the workflows
	actionlint .github/workflows/*.yml
