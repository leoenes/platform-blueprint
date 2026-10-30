# Repository-level checks. `make check` is what CI runs; everything in it
# works offline. Infrastructure plan/apply helpers live in infra/terraform.

ENVS := $(wildcard infra/platform-config/environments/*.yaml)
SH   := $(shell find .github infra/delivery -name '*.sh')

.DEFAULT_GOAL := help
.PHONY: help check fmt fmt-check lint-shell lint-actions lint-helm inventory inventory-check stages render

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-16s %s\n", $$1, $$2 }'

check: fmt-check lint-shell lint-actions lint-helm inventory-check stages ## everything CI runs

fmt: ## format Terraform and Terragrunt files
	tofu fmt -recursive infra/terraform
	terragrunt hcl fmt --working-dir infra/terraform

fmt-check: ## fail on unformatted Terraform
	tofu fmt -recursive -check -diff infra/terraform

lint-shell: ## shellcheck every script
	shellcheck -x $(SH)

lint-actions: ## actionlint the workflows
	actionlint .github/workflows/*.yml

lint-helm: ## lint and render the platform chart for every cluster file
	@for env in $(ENVS); do \
	  echo "== $$env"; \
	  helm lint infra/helm-charts/platform-apps -f $$env --quiet; \
	  helm template platform-apps infra/helm-charts/platform-apps -f $$env > /dev/null; \
	done
	helm lint infra/helm-charts/service --quiet
	helm template example infra/helm-charts/service -f infra/platform-config/environments/nonprod-eu-west-2.yaml -f apps/example-api/.platform/values.yaml --set image.tag=rel-test > /dev/null

inventory: ## regenerate digger.yml from the directory tree
	.github/scripts/digger/generate-inventory.sh

inventory-check: ## fail if digger.yml is stale
	.github/scripts/digger/generate-inventory.sh --check

stages: ## dry-run the dependency staging over the whole inventory
	@SELECTION_SCOPE=drift GITHUB_OUTPUT=/dev/stdout .github/scripts/digger/compute-impacted.sh | grep -E 'count'

render: ## render the platform chart for one cluster: make render ENV=nonprod-eu-west-2
	helm template platform-apps infra/helm-charts/platform-apps -f infra/platform-config/environments/$(ENV).yaml
