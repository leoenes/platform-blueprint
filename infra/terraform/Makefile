# Local helpers. CI never uses these; Digger does. They exist for ad-hoc
# plans and for the rare bootstrap apply.
#
#   make login   INSTANCE=nonprod/uk/eu-west-2
#   make plan    LAYER=workloads/eks INSTANCE=nonprod/uk/eu-west-2
#   make plan-ro LAYER=workloads/eks INSTANCE=prod/uk/eu-west-2   # read-only profile, cannot mutate
#   make apply   LAYER=foundations/iam-github INSTANCE=shared/deployment/eu-west-2
#   make fmt

LAYER    ?=
INSTANCE ?=
TG       ?= terragrunt
WORKDIR  := layers/$(LAYER)/environments/$(INSTANCE)

STAGE   := $(word 1,$(subst /, ,$(INSTANCE)))
LEADER  := $(word 2,$(subst /, ,$(INSTANCE)))
ENV     := acme-$(STAGE)-$(LEADER)
ENV     := $(subst acme-shared-,acme-,$(ENV))

SSO_PROFILE := $(ENV)-administrator
RO_PROFILE  := $(ENV)-readonly

.DEFAULT_GOAL := help
.PHONY: help login plan plan-ro apply fmt _check

help:
	@grep -E '^#   make' $(MAKEFILE_LIST) | sed 's/^#   //'

_check:
	@test -n "$(LAYER)"    || (echo "LAYER required, e.g. workloads/eks" && exit 1)
	@test -n "$(INSTANCE)" || (echo "INSTANCE required, e.g. nonprod/uk/eu-west-2" && exit 1)
	@test -d "$(WORKDIR)"  || (echo "$(WORKDIR) not found" && exit 1)

login:
	aws sso login --profile $(SSO_PROFILE)

plan: _check
	cd $(WORKDIR) && $(TG) plan

# Read-only plans refuse to run with ambient credentials so nobody can
# accidentally plan prod with an admin session.
plan-ro: _check
	@if [ -n "$${AWS_ACCESS_KEY_ID:-}$${TG_CI_MODE:-}" ]; then echo "plan-ro needs SSO profiles, not ambient credentials" >&2; exit 1; fi
	cd $(WORKDIR) && AWS_PROFILE=$(RO_PROFILE) TG_PROVIDER_AWS_PROFILE=$(RO_PROFILE) $(TG) plan -lock=false

apply: _check
	cd $(WORKDIR) && $(TG) apply

fmt:
	tofu fmt -recursive layers modules setup
	$(TG) hcl fmt
