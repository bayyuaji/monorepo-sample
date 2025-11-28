REGISTRY_PORT ?= 5001
REGISTRY_NAME ?= kind-registry
KIND_CLUSTER_NAME ?= demo-cluster

# Optional local images (not used by default manifests, but ready for future)
GO_IMAGE := localhost:$(REGISTRY_PORT)/my-monorepo-go:v1
NODE_IMAGE := localhost:$(REGISTRY_PORT)/my-monorepo-node:v1

# --- GitHub ARC (self-hosted runners) ---
ARC_CONTROLLER_NAMESPACE ?= arc-systems
ARC_RUNNERS_NAMESPACE    ?= arc-runners
ARC_CONTROLLER_RELEASE   ?= arc
ARC_RUNNERSET_RELEASE    ?= arc-runner-set

# Set these when calling arc-install-runners:
#   GITHUB_CONFIG_URL = https://github.com/OWNER/REPO or https://github.com/ORG
#   GITHUB_PAT        = ghp_xxx (PAT with repo / admin:org as needed)
GITHUB_CONFIG_URL ?=
GITHUB_PAT        ?=

.PHONY: help
help:
	@echo "Targets:"
	@echo "  registry-up          - start local docker registry on port $(REGISTRY_PORT)"
	@echo "  kind-up              - create kind cluster wired to local registry"
	@echo "  kind-down            - delete kind cluster"
	@echo "  build-go             - build Go service image (local, optional)"
	@echo "  build-node           - build Node service image (local, optional)"
	@echo "  push-images          - push images to local registry"
	@echo "  deploy               - apply kustomize overlay (apps + observability)"
	@echo "  argocd-install       - install Argo CD into argocd namespace"
	@echo "  argocd-app           - apply Argo CD Application for this repo"
	@echo "  argocd-password      - print Argo CD initial admin password"
	@echo "  arc-install-controller - install Actions Runner Controller (controller)"
	@echo "  arc-install-runners  - install runner scale set (self-hosted runners)"
	@echo "  all                  - registry-up + kind-up + deploy"

registry-up:
	@if [ -z "$$(docker ps -q -f name=$(REGISTRY_NAME))" ]; then \
	  if [ -z "$$(docker ps -aq -f name=$(REGISTRY_NAME))" ]; then \
	    echo "Starting new registry container..."; \
	    docker run -d --restart=always -p $(REGISTRY_PORT):5000 --name $(REGISTRY_NAME) registry:2; \
	  else \
	    echo "Starting existing registry container..."; \
	    docker start $(REGISTRY_NAME); \
	  fi \
	else \
	  echo "Registry already running"; \
	fi
	@docker network connect "kind" "$(REGISTRY_NAME)" 2>/dev/null || true

kind-up:
	kind create cluster --name $(KIND_CLUSTER_NAME) --config kind-config.yaml || true

kind-down:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

build-go:
	docker build -t $(GO_IMAGE) ./go-service

build-node:
	docker build -t $(NODE_IMAGE) ./node-service

push-images:
	docker push $(GO_IMAGE)
	docker push $(NODE_IMAGE)

deploy:
	kubectl apply -k k8s/overlays/local

all: registry-up kind-up deploy
	@echo "Cluster, registry (optional), and k8s manifests are applied."

# --- Argo CD ---

ARGOCD_NAMESPACE := argocd

.PHONY: argocd-install argocd-app argocd-password

argocd-install:
	@echo "Creating Argo CD namespace..."
	kubectl apply -f argocd/namespace.yaml
	@echo "Installing Argo CD (upstream manifest)..."
	kubectl apply -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-app:
	@echo "Creating Argo CD Application for demo platform..."
	kubectl apply -f argocd/app-demo.yaml

argocd-password:
	@echo "Argo CD initial admin password:"
	kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# --- Actions Runner Controller (self-hosted GitHub runners) ---

.PHONY: arc-install-controller arc-install-runners

arc-install-controller:
	@if [ -z "$$(which helm)" ]; then echo "helm not found in PATH"; exit 1; fi
	@echo "Installing Actions Runner Controller (controller) into $(ARC_CONTROLLER_NAMESPACE)..."
	helm upgrade --install $(ARC_CONTROLLER_RELEASE) \
		--namespace "$(ARC_CONTROLLER_NAMESPACE)" \
		--create-namespace \
		oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
		--version 0.13.0

arc-install-runners:
	@if [ -z "$(GITHUB_CONFIG_URL)" ]; then \
		echo "GITHUB_CONFIG_URL is required (e.g. https://github.com/OWNER/REPO)"; exit 1; \
	fi
	@if [ -z "$(GITHUB_PAT)" ]; then \
		echo "GITHUB_PAT is required (PAT with repo/admin:org scopes)"; exit 1; \
	fi
	@if [ -z "$$(which helm)" ]; then echo "helm not found in PATH"; exit 1; fi
	@echo "Creating runner scale set in $(ARC_RUNNERS_NAMESPACE) for $(GITHUB_CONFIG_URL)..."
	helm upgrade --install $(ARC_RUNNERSET_RELEASE) \
		--namespace "$(ARC_RUNNERS_NAMESPACE)" \
		--create-namespace \
		oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
		--version 0.13.0 \
		--set githubConfigUrl="$(GITHUB_CONFIG_URL)" \
		--set githubConfigSecret.github_token="$(GITHUB_PAT)"

