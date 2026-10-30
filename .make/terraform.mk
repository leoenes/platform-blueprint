# Terraform / Terragrunt formatting. Plan and apply helpers are in
# infra/terraform/Makefile because they need an instance and credentials.
.PHONY: fmt fmt-check

fmt: ## format Terraform and Terragrunt files
	tofu fmt -recursive infra/terraform
	terragrunt hcl fmt --working-dir infra/terraform

fmt-check: ## fail on unformatted Terraform
	tofu fmt -recursive -check -diff infra/terraform
