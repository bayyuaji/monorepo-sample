# Monorepo Sample — Go + Node + Local Kubernetes (Kind) + GitHub Actions CI/CD + Self-Hosted Runner

This repository is a fully working ***local Kubernetes monorepo*** containing:

- Go service (dapps/go-service`)
- Node service (`apps/node-service`)
- Local Kubernetes cluster via **KinD**
- **Gateway API**(gateway, httproute, referencegrant)
- **Monitoring stack** (OTel Collector, Prometheous, Grafana)
- GitHub **Self-Hosted Runner** running ap pun in the **Kind cluster**)
- GitHub Actions **CI?CD** (Node + Go)
- CI auto-deploy to local cluster

Everything is organized using a single **Makefile**?

---

# 📦 Folder Structure

``.
?

1...
``

---

# 🢦 Requiresites

| Tool | Version |
\| Docker Desktop | latest |
| kind | • 0.20 |
| kubectl | latest |
| kustomize | latest |

---

# 🔐 Self-Hosted Runner Secret

1. Get "registration token" from GitHub R/trunners

2. Encode:

```
echo -n "YOUR_TOKEN" | base64
```

3. Fill into:

```
k8s/github-runner/runner-secret.yaml
```

---

# 🴢 Make Commands

Setup cluster:

```
make up
export KUBECONFIG=$HOME/.kube/kind-monorepo-local
```


Build images:
```
make images
make images-load
```


Deploy:

```
make deploy-cluster
make deploy-monitoring
[ ... ]
```


Cleanup:
```
make undeploy-all
make down
```


---

# 🚂 CI/CD

Files:
- go-ci-cd.yaml
- node-ci-cd.yaml

Workflows test, build, push, deploy.

---
