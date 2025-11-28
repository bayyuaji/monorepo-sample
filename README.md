# Monorepo Sample — Go + Node + Local Kubernetes (KinD) + Gateway API + Monitoring Stack + GitHub ARC Runner

This repository contains a complete monorepo setup designed for **local Kubernetes development**, **GitOps-style deployment**, and **CI/CD using GitHub Actions with a self-hosted runner running inside KinD**.

Included components:

- Go service (`apps/go-service`)
- Node.js service (`apps/node-service`)
- KinD (Kubernetes-in-Docker) development cluster
- Gateway API (GatewayClass, Gateway, HTTPRoute, ReferenceGrant)
- Monitoring stack (OpenTelemetry Collector, Prometheus, Grafana)
- GitHub Actions Runner Controller (ARC) for scalable self-hosted runners
- Makefile automation for building, deploying, and local testing

---

# Folder Structure
Everything is organized using a single **Makefile**

```
.
├── Makefile
├── README.md
├── apps
│   ├── go-service
│   │   ├── Dockerfile
│   │   ├── go.mod
│   │   ├── go.sum
│   │   └── main.go
│   └── node-service
│       ├── Dockerfile
│       ├── index.js
│       ├── package.json
│       └── test
│           └── basic.test.js
└── k8s
    ├── cluster
    │   ├── base
    │   │   ├── gateway.yaml
    │   │   ├── gatewayclass.yaml
    │   │   ├── httproute.yaml
    │   │   ├── kustomization.yaml
    │   │   ├── namespace.yaml
    │   │   ├── refgrant-go.yaml
    │   │   └── refgrant-node.yaml
    │   └── gateway-crds
    │       └── kustomization.yaml
    ├── gateway
    │   ├── gateway.yaml
    │   ├── gatewayclass.yaml
    │   ├── httproute.yaml
    │   ├── kustomization.yaml
    │   ├── refgrant-go.yaml
    │   └── refgrant-node.yaml
    ├── github-runner
    │   ├── autoscalingrunnerset.yaml
    │   ├── github-config-secret.yaml
    │   ├── kustomization.yaml
    │   └── runner-rbac.yaml
    ├── go-service
    │   ├── base
    │   │   ├── deployment.yaml
    │   │   ├── kustomization.yaml
    │   │   └── service.yaml
    │   └── overlays
    │       ├── ci-cd
    │       │   ├── image-patch.yaml
    │       │   └── kustomization.yaml
    │       └── local
    │           ├── image-patch.yaml
    │           └── kustomization.yaml
    ├── monitoring
    │   ├── grafana-config.yaml
    │   ├── grafana-deployment.yaml
    │   ├── grafana-service.yaml
    │   ├── kustomization.yaml
    │   ├── otel-collector-config.yaml
    │   ├── otel-collector.yaml
    │   ├── prometheus-config.yaml
    │   └── prometheus.yaml
    └── node-service
        ├── base
        │   ├── deployment.yaml
        │   ├── kustomization.yaml
        │   └── service.yaml
        └── overlays
            ├── ci-cd
            │   ├── image-patch.yaml
            │   └── kustomization.yaml
            └── local
                ├── image-patch.yaml
                └── kustomization.yaml

22 directories, 50 files
```

Each folder contains:

- **base** manifests  
- **overlays/local** for local KinD deployment  
- **overlays/ci-cd** for automated CI/CD image patching  

---

# Prerequisites

Install the following tools before using this project:

```
-----------------------------------------------------------------------------
|    Tools   |                         Requirement                          |
|------------|--------------------------------------------------------------|
| Docker     | latest                                                       |
| kubectl    | ≥ 1.26                                                       |
| kind       | ≥ 0.20                                                       |
| kustomize  | latest                                                       |
| helm       | ≥ 3.13                                                       |
| GitHub PAT | scopes: `repo`, `read:packages`, `admin:org` (if org runner) |
-----------------------------------------------------------------------------
```

---

# Environment Variables

Set these before installing the GitHub ARC runner:

```
export GHCR_TOKEN="ghp_xxx_your_pat_here"
export GHCR_USERNAME="bayyuaji"
export KUBECONFIG=$HOME/.kube/kind-monorepo-local
```

#  Getting Started

1. Create The KinD Cluster
```
make up
export KUBECONFIG=$HOME/.kube/kind-monorepo-local

```
2. Build and Load Local Images
```
make images
make images-load
```
3. Deploy Core Components

```
make deploy-cluster
make deploy-monitoring
make deploy-go
make deploy-node

```
To deploy everything at once:
```
make deploy
```
---

# GitHub Self-Hosted Runner (ARC)

This repository uses **GitHub Actions Runner Controller (ARC)** to run CI/CD workloads **inside the KinD cluster**.  
ARC automatically manages:

- Self-hosted runner pods
- Auto-scaling based on job demands
- Ephemeral runners for improved security
- Runner registration lifecycle

This setup ensures that **all CI/CD pipelines run locally** without relying on GitHub-hosted runners.


## 1. Set Required Environment Variables

Before installing ARC, export your GitHub token (PAT) and username:

```
export GHCR_TOKEN="ghp_xxx_your_pat_here"     # must have repo + read:packages scopes
export GHCR_USERNAME="bayyuaji"
export KUBECONFIG=$HOME/.kube/kind-monorepo-local
```

## 2. Install the GitHub ARC Controller & Runner Scale Set
Install ARC controller + CRDs + AutoScalingRunnerSet using the Makefile:
```
make deploy-github-runner

```
This command performs:
1. Authentication to ghcr.io using your Github PAT
2. INstallation of ARC controller & ARC CRDs + default Runner Scale Set
3. Deployment of your custom Kustomize resources under k8s/github-runner

## 3. Verify Installation
Check ARC controller:
```
kubectl get pods -n github-runner
```
You should see:
```
arc-gha-rs-controller-xxxxx
```
Check runner scale sets:
```
kubectl get autoscalingrunnersets.actions.github.com -n github-runner
```
Expected output:
```
arc-crds   1/1    Running
```

## 4. Verify Runner in Github UI

```
GitHub → Repository → Settings → Actions → Runners → Runner Scale Sets
```
## 5. Using Runner in Github Workflows
Your GitHub Actions workflow should reference the scale set name exactly:
```
runs-on: arc-crds
```

## 6.  Testing Go and Node Service

Go
```
kubectl port-forward svc/go-service -n go-service 8080:80
curl http://localhost:8080
```

Node
```
kubectl port-forward svc/node-service -n node-service 3000:80
curl http://localhost:3000
```

## 7. Monitoring Stack
Prometheus
```
kubectl port-forward svc/prometheus -n monitoring 9090:9090
http://localhost:9090
```

Grafana
```
kubectl port-forward svc/grafana -n monitoring 3001:3000
http://localhost:3001
```
---

## Cleanup
Delete all workloads:
```
make undeploy-all

```
Delete Kind\D cluster
```
make undeploy-all
```

---
# CI/CD

Files:
- go-ci-cd.yaml
- node-ci-cd.yaml

Workflows test, build, push, deploy.

---
