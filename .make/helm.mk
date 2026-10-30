# Charts: lint and render for every cluster file, so a template error shows
# up before ArgoCD sees it.
.PHONY: lint-helm render

lint-helm: ## lint and render the platform chart for every cluster file
	@for env in $(ENVS); do \
	  echo "== $$env"; \
	  helm lint infra/helm-charts/platform-apps -f $$env --quiet; \
	  helm template platform-apps infra/helm-charts/platform-apps -f $$env > /dev/null; \
	done
	helm lint infra/helm-charts/service --quiet
	helm template example infra/helm-charts/service -f infra/platform-config/environments/nonprod-eu-west-2.yaml -f apps/example-api/.platform/values.yaml --set image.tag=rel-test > /dev/null

render: ## render the platform chart for one cluster: make render ENV=nonprod-eu-west-2
	helm template platform-apps infra/helm-charts/platform-apps -f infra/platform-config/environments/$(ENV).yaml
