# Local Kubernetes Platform on Kind  
### GitOps • Observability • Argo CD • GitHub Self-Hosted Runners • Multi-Namespace Apps

This repository provides a fully working **local Kubernetes platform** using **Kind**, with:

- Multi-namespace sample applications  
- Argo CD GitOps  
- Observability stack (OTel Collector + Prometheus + Grafana)  
- Optional GitHub Actions **self-hosted runners** via ARC  
- Optional local registry for container builds  
- Automated with a single **Makefile**

Perfect for SRE, DevOps, platform engineering practice, demos, and experimentation.

---

# Repository Structure (Clean)

.
├── clusters/
│   └── local/
│       └── argocd-apps.yaml
│
├── infrastructure/
│   ├── observability/
│   ├── argocd/
│   ├── runners/
│   └── ...
│
├── services/
│   ├── go-service/
│   └── node-service/
│
├── deploy/
│   ├── base/
│   └── overlays/
│
├── kind/
│   ├── cluster.yaml
│   └── registry.yaml
│
├── Makefile
└── README.md


---

## Prerequisites

Install:
- Docker  
- Kind  
- kubectl  
- Helm  
- (Optional) GitHub PAT for ARC

---

## Setup

### 1. (Optional) Start local registry
```bash
make registry-up

### 2. Create Kind cluster
```bash
make kind-up

### 3. Deploy applications + observability
```bash
make deploy

Check:
```bash
kubectl get pods -n go-apps
kubectl get pods -n node-apps
kubectl get pods -n observability

## Observability

### Access Grafana
```bash
kubectl port-forward -n observability svc/grafana 3000:3000

URL: http://localhost:3000
Login:
user: admin
pass: admin
Prometheus datasource is pre-configured.

## ArgoCD (GitOps)

### 1. Install ArgoCD
```bash
make argocd-install

### 2. Get ArgoCD password
```bash
make argocd-password

### 3. Deploy ArgoCD application
```bash
make argocd-aoo

### 4. Access ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443

Open: https://localhost:8080
Login using password from previous step.

## GitHub Self-Hosted Runners
ARC runs GitHub Action jobs inside the cluster.

### 1. Install ARC controller
```bash
make arc-install-controller

### 2. Install runner scale set
Required:
| Variable          | Example                                                        |
| ----------------- | -------------------------------------------------------------- |
| GITHUB_CONFIG_URL | [https://github.com/OWNER/REPO](https://github.com/OWNER/REPO) |
| GITHUB_PAT        | ghp_xxx                                                        |

Run:
```bash
make arc-install-runners \
  GITHUB_CONFIG_URL="https://github.com/YOURORG/YOURREPO" \
  GITHUB_PAT="ghp_xxx"

Check:
```bash
kubectl get pods -n arc-runners

Workflow:
```bash
runs-on: arc-runner-set

## Values to Update

| File                    | Field               | Description                  |
|-------------------------|---------------------|------------------------------|
| `argocd/app-demo.yaml`  | `repoURL`           | Your GitHub repository URL   |
| Makefile                | `GITHUB_CONFIG_URL` | GitHub repo or org URL       |
| Makefile                | `GITHUB_PAT`        | GitHub Personal Access Token |
| Grafana configuration   | `password`          | Change admin password        |
| Kustomize manifests     | `image`             | Use custom-built images      |

## Cleanup

Delete cluster:
```bash
make kind-down

Delete registry:
```bash
docker rm -f kind-registry

