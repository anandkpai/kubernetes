# Local Kubernetes Playground (kind + NGINX Ingress + ArgoCD + Kubernetes Dashboard)

This repo contains a local Kubernetes playground running on **kind** (Kubernetes in Docker), with:

- **NGINX Ingress Controller** (in the `ingress-nginx` namespace)
- **ArgoCD** (GitOps controller, `argocd` namespace)
- **Kubernetes Dashboard** (`kubernetes-dashboard` namespace)
- **nginx-demo** app in the **default** namespace with TLS ingress
- **TLS secrets** generated from a wildcard certificate via **Kustomize**
- An optional **ingress port-forward** on **port 8443** from WSL to the NGINX ingress controller

The layout is designed to be GitOps-friendly and easy to reset/recreate inside a local environment such as WSL.

---

## 📁 Directory Structure

```
KUBERNETES/
  argocd/
    argocd-ingress.yaml
    argocd-root.yaml
    kustomization.yaml

  certs/
    wildcard.localtest.me-key.pem
    wildcard.localtest.me.pem

  kind/
    kind-config.yaml

  kubernetes-dashboard/
    kubernetes-dashboard-admin-user.yaml
    kubernetes-dashboard-ingress.yaml
    kustomization.yaml

  nginx-demo/
    nginx-demo-app.yaml
    nginx-demo-ingress.yaml
    kustomization.yaml

  tokens/
    argocd.token
    dashboard.token

  .gitignore
  kustomization.yaml
```

### Folder Purpose

| Directory | Description |
|----------|-------------|
| `argocd/` | ArgoCD ingress + ArgoCD root Application + TLS secret generator |
| `kubernetes-dashboard/` | Dashboard admin user + ingress + TLS secret generator |
| `nginx-demo/` | Demo nginx deployment + service + ingress + TLS secret generator |
| `certs/` | Wildcard certificate used for all TLS secrets |
| `kind/` | Kind cluster configuration |
| `tokens/` | Optional login token storage |
| Root Kustomization | Combines all components into a single GitOps component |

---

## 🛠 Prerequisites

You need the following installed in your WSL/Linux environment:

- Docker
- Kind
- Kubectl
- Bash

Optional (but recommended):

- Kustomize (`kubectl apply -k` works without it)
- Systemd user services enabled inside WSL for long-running port-forwards

---

# 🚀 Installation Workflow

You must run the setup steps **from inside the KUBERNETES directory**.

## 1. Create the Kind cluster

```bash
./install-kind.sh
```

This script:

- Creates a cluster using `kind/kind-config.yaml`
- Names the cluster `kind`
- Skips creation if the cluster already exists

---

## 2. Install NGINX Ingress Controller

```bash
./install-nginx.sh
```

This script:

- Installs the official ingress-nginx controller (Kind-optimized manifest)
- Waits for the controller to become ready

---

## 3. Install ArgoCD core + apply ArgoCD kustomization

```bash
./install-agocd.sh
```

This script:

- Ensures `argocd` namespace exists
- Installs ArgoCD core from upstream
- Applies the Kustomize overlay (TLS + ingress + root Application)

---

## 4. Install Kubernetes Dashboard + apply Dashboard Kustomization

```bash
./install-kubernetes-dashboard.sh
```

This script:

- Installs the official Kubernetes Dashboard
- Applies TLS + ingress + RBAC admin user

---

## 5. Apply the full repo Kustomization

```bash
kubectl apply -k .
```

This applies:

- ArgoCD ingress + TLS generator
- Dashboard ingress + TLS generator
- nginx-demo app + ingress + TLS generator

---

# 🌐 Accessing Applications (via port-forwarded ingress)

The environment assumes that **only one port-forward service exists**:

### ✔ Ingress mapped from WSL → Kind:

```
localhost:8443 → ingress-nginx-controller:443
```

If you are running a systemd service, it likely runs:

```bash
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8443:443
```

Once that service is active, you can access ALL ingresses via:

```
https://<hostname>:8443
```

This repo configures ingress hosts:

- `nginx.localtest.me`
- `argocd.localtest.me`
- `dashboard.localtest.me`

So in practice you access:

### nginx demo
```
https://nginx.localtest.me:8443
```

### ArgoCD UI
```
https://argocd.localtest.me:8443
```

### Kubernetes Dashboard
```
https://dashboard.localtest.me:8443
```

### IMPORTANT: Update /etc/hosts
Ensure your host (Windows/macOS/Linux) has:

```
127.0.0.1 nginx.localtest.me argocd.localtest.me dashboard.localtest.me
```

---

# 🔐 Login Instructions

## ArgoCD

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret   -o jsonpath="{.data.password}" | base64 -d && echo
```

Login with:

- **username:** `admin`
- **password:** (from command above)

---

## Kubernetes Dashboard

Generate a login token:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```
or run the script under kubernetes-dashboard/scripts

Paste the token into the login form at:

```
https://dashboard.localtest.me:8443/#/login
```

---

# 🧪 nginx-demo App

The nginx demo application is a simple test workload consisting of:

- Deployment (`nginx-demo`)
- Service (`nginx-demo-svc`)
- Ingress (`nginx-demo-ingress`)

It exists **only for verifying ingress functionality**.  
It does **not** affect the ingress controller in any way.

The ingress routes:

```
https://nginx.localtest.me:8443 → nginx-demo-svc:80
```

---

# 🔐 TLS Secrets

TLS secrets are created automatically via Kustomize:

```
certs/
  wildcard.localtest.me.pem
  wildcard.localtest.me-key.pem
```

Generated secrets:

| Namespace | Secret Name |
|-----------|--------------|
| argocd | `argocd-tls` |
| kubernetes-dashboard | `dashboard-tls` |
| default | `nginx-tls` |

All workloads use these secrets in their ingress specifications.

---

# ♻️ Resetting the Environment

To fully reset / recreate your environment:

```bash
kind delete cluster --name kind

./scripts/install-kind.sh
./scripts/install-nginx.sh
./scripts/install-agocd.sh
./scripts/install-kubernetes-dashboard.sh
kubectl apply -k .
```

Make sure your 8443 port-forward service is running after recreation.

---

# 📌 Notes

- All TLS secrets are generated declaratively by Kustomize from PEM files
- Only **one** port-forward is required (ingress controller 8443 → 443)
- No dedicated port-forward is needed for ArgoCD
- nginx-demo is only a sample app and can be removed without affecting the system
- This repo is intended for **local development and experimentation**, not production use

---
