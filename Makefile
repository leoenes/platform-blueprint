# Entry point. Each concern lives in .make/<name>.mk; `make help` lists every
# target across them. `make check` is the CI contract.

ENVS := $(wildcard infra/platform-config/environments/*.yaml)
SH   := $(shell find .github infra/delivery .make -name '*.sh')

include .make/*.mk

.DEFAULT_GOAL := help
.PHONY: help check

help: ## list targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-16s %s\n", $$1, $$2 }'

check: fmt-check lint-shell lint-actions lint-helm inventory-check stages docs-check ## everything CI runs
