# digger.yml is generated from the directory tree; never edit it by hand.
.PHONY: inventory inventory-check stages

inventory: ## regenerate digger.yml from the directory tree
	.github/scripts/digger/generate-inventory.sh

inventory-check: ## fail if digger.yml is stale
	.github/scripts/digger/generate-inventory.sh --check

stages: ## dry-run the dependency staging over the whole inventory
	@SELECTION_SCOPE=drift GITHUB_OUTPUT=/dev/stdout .github/scripts/digger/compute-impacted.sh | grep -E 'count'
