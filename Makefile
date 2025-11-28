SHELL := /bin/bash
.DEFAULT_GOAL := help

# -------------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------------

CLUSTER_NAME        ?= monorepo-local
KIND_CONFIG         ?= kind/config.yaml
KUBECONFIG_PATH     ?= $(HOME)/.kube/kind-$(CLUSTER_NAME)

# Image names (tanpa registry; akan di-load ke KinD via kind load)
GO_APP_NAME         ?= go-service
NODE_APP_NAME       ?= node-service

GO_APP_IMAGE        ?= monorepo/$(GO_APP_NAME):local
NODE_APP_IMAGE      ?= monorepo/$(NODE_APP_NAME):local

GO_APP_PATH         ?= apps/go-service
NODE_APP_PATH       ?= apps/node-service

# Kustomize paths
K8S_GATEWAY_CRDS_PATH ?= k8s/cluster/gateway-crds
K8S_CLUSTER_PATH      ?= k8s/cluster/base
K8S_GO_LOCAL_PATH     ?= k8s/go-service/overlays/local
K8S_NODE_LOCAL_PATH   ?= k8s/node-service/overlays/local
K8S_MONITORING_PATH   ?= k8s/monitoring

# -------------------------------------------------------------------
# HELP
# -------------------------------------------------------------------

.PHONY: help
help:
	@echo ""
	@echo "Monorepo Go + Node local K8s Make targets"
	@echo ""
	@echo "  CLUSTER"
	@echo "    make up                   - Create KinD cluster"
	@echo "    make down                 - Delete KinD cluster"
	@echo ""
	@echo "  IMAGES (local, then loaded into KinD)"
	@echo "    make images               - Build Go + Node images"
	@echo "    make images-go            - Build Go image"
	@echo "    make images-node          - Build Node image"
	@echo "    make images-load          - kind load docker-image for Go + Node"
	@echo ""
	@echo "  DEPLOY (Kustomize + overlays)"
	@echo "    make deploy-cluster       - Deploy Gateway API CRDs + namespaces + Gateway + HTTPRoutes + ReferenceGrants"
	@echo "    make deploy-monitoring    - Deploy OTel Collector + Prometheus + Grafana"
	@echo "    make deploy-go            - Deploy Go service (overlays/local)"
	@echo "    make deploy-node          - Deploy Node service (overlays/local)"
	@echo "    make deploy               - Deploy cluster + monitoring + Go + Node"
	@echo ""
	@echo "  CLEANUP"
	@echo "    make undeploy-go          - Delete Go service"
	@echo "    make undeploy-node        - Delete Node service"
	@echo "    make undeploy-monitoring  - Delete monitoring stack"
	@echo "    make undeploy-cluster     - Delete cluster base objects"
	@echo "    make undeploy-all         - Delete everything"
	@echo ""
	@echo "  UTILS"
	@echo "    make status               - Show nodes & pods"
	@echo "    make kube-context         - Print KUBECONFIG export line"
	@echo ""
	@echo "Tips:"
	@echo "  After 'make up', run:"
	@echo "    export KUBECONFIG=$(KUBECONFIG_PATH)"
	@echo ""

# -------------------------------------------------------------------
# KIND CLUSTER
# -------------------------------------------------------------------

.PHONY: up
up:
	@echo ">>> Creating KinD cluster '$(CLUSTER_NAME)'..."
	@if ! command -v kind >/dev/null 2>&1; then echo "kind not installed"; exit 1; fi
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
	  echo "KinD cluster $(CLUSTER_NAME) already exists"; \
	else \
	  if [ -f "$(KIND_CONFIG)" ]; then \
	    echo "Using kind config: $(KIND_CONFIG)"; \
	    KUBECONFIG=$(KUBECONFIG_PATH) kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG); \
	  else \
	    echo "No kind config found, using defaults"; \
	    KUBECONFIG=$(KUBECONFIG_PATH) kind create cluster --name $(CLUSTER_NAME); \
	  fi; \
	fi
	@echo ""
	@echo ">>> IMPORTANT: Set your kubeconfig for kubectl access:"
	@echo "export KUBECONFIG=$(KUBECONFIG_PATH)"
	@echo ""
	@echo ">>> Verify with:"
	@echo "kubectl cluster-info"
	@echo ""

.PHONY: down
down:
	@echo ">>> Deleting KinD cluster '$(CLUSTER_NAME)'..."
	@kind delete cluster --name $(CLUSTER_NAME) || true
	@rm -f $(KUBECONFIG_PATH) || true

# -------------------------------------------------------------------
# IMAGES
# -------------------------------------------------------------------

.PHONY: images
images: images-go images-node

.PHONY: images-go
images-go:
	@echo ">>> Building Go service image: $(GO_APP_IMAGE)"
	@docker build -t $(GO_APP_IMAGE) $(GO_APP_PATH)

.PHONY: images-node
images-node:
	@echo ">>> Building Node service image: $(NODE_APP_IMAGE)"
	@docker build -t $(NODE_APP_IMAGE) $(NODE_APP_PATH)

.PHONY: images-load
images-load:
	@echo ">>> Loading images directly into KinD cluster '$(CLUSTER_NAME)'..."
	@kind load docker-image $(GO_APP_IMAGE)   --name $(CLUSTER_NAME)
	@kind load docker-image $(NODE_APP_IMAGE) --name $(CLUSTER_NAME)

# -------------------------------------------------------------------
# DEPLOY
# -------------------------------------------------------------------

.PHONY: deploy
deploy: deploy-cluster deploy-monitoring deploy-go deploy-node
	@echo ">>> Cluster + monitoring + Go + Node deployed."

.PHONY: deploy-cluster
deploy-cluster:
	@echo ">>> Step 1: Installing Gateway API CRDs via kustomize..."
	@kubectl apply -k $(K8S_GATEWAY_CRDS_PATH)
	@echo ">>> Step 2: Applying cluster base:"
	@echo "    - Namespaces"
	@echo "    - GatewayClass"
	@echo "    - Gateway"
	@echo "    - HTTPRoutes"
	@echo "    - ReferenceGrants"
	@kubectl apply -k $(K8S_CLUSTER_PATH)
	@echo ">>> Cluster networking ready."

.PHONY: deploy-monitoring
deploy-monitoring:
	@echo ">>> Deploying monitoring stack (OTel Collector + Prometheus + Grafana)..."
	@kubectl apply -k $(K8S_MONITORING_PATH)

.PHONY: deploy-go
deploy-go:
	@echo ">>> Deploying Go service (overlay: local)..."
	@kubectl apply -k $(K8S_GO_LOCAL_PATH)

.PHONY: deploy-node
deploy-node:
	@echo ">>> Deploying Node service (overlay: local)..."
	@kubectl apply -k $(K8S_NODE_LOCAL_PATH)

# -------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------

.PHONY: undeploy-go
undeploy-go:
	@echo ">>> Deleting Go service..."
	@kubectl delete -k $(K8S_GO_LOCAL_PATH) --ignore-not-found

.PHONY: undeploy-node
undeploy-node:
	@echo ">>> Deleting Node service..."
	@kubectl delete -k $(K8S_NODE_LOCAL_PATH) --ignore-not-found

.PHONY: undeploy-monitoring
undeploy-monitoring:
	@echo ">>> Deleting monitoring stack..."
	@kubectl delete -k $(K8S_MONITORING_PATH) --ignore-not-found

.PHONY: undeploy-cluster
undeploy-cluster:
	@echo ">>> Deleting cluster base resources..."
	@kubectl delete -k $(K8S_CLUSTER_PATH) --ignore-not-found

.PHONY: undeploy-all
undeploy-all: undeploy-go undeploy-node undeploy-monitoring undeploy-cluster
	@echo ">>> Everything deleted."

# -------------------------------------------------------------------
# UTILS
# -------------------------------------------------------------------

.PHONY: status
status:
	@echo ">>> Nodes:"
	@kubectl get nodes || true
	@echo ""
	@echo ">>> Pods (all namespaces):"
	@kubectl get pods -A || true

.PHONY: kube-context
kube-context:
	@echo "export KUBECONFIG=$(KUBECONFIG_PATH)"

