# Local Kubernetes Playground (kind + NGINX Ingress + ArgoCD + Kubernetes Dashboard + Apps)

This repository describes a **local Kubernetes playground** based on three Git repos that work together:

- **`kubernetes`** – bootstrap: Kind cluster, NGINX Ingress, ArgoCD, TLS secrets, root ArgoCD Application, dashboard ingress.
- **`argocd-platform`** – ArgoCD `Application` definitions:
  - `nginx-demo` app
  - `kubernetes-dashboard` app
  - `dagster` app (Helm-based)
- **`examples`** – actual workloads:
  - `nginx-demo` deployment & ingress
  - `dagster` example image & code

The design is focused on **local development, experimentation and GitOps**, not production use.

---

## ⚡ Quickstart

From the **`kubernetes`** repo root:

```bash
# 1. Create Kind cluster
./scripts/install-kind.sh

# 2. Install NGINX ingress controller
./scripts/install-nginx.sh

# 3. Install ArgoCD
./scripts/install-agocd.sh

# 4. Bootstrap ArgoCD to point at the argocd-platform repo
kubectl apply -k argocd-root-application

# 5. Create TLS secrets for ArgoCD + apps
cd scripts
./create-argocd-tls-secret.sh
./create-nginx-demo-tls.sh
./create-dashboard-tls-secret.sh
./create-dagster-tls.sh


After this:

- ArgoCD should be up in `argocd` namespace.
- NGINX ingress is running in `ingress-nginx`.
- TLS secrets exist for:
  - `argocd-tls` (namespace: `argocd`)
  - `nginx-demo-tls` (namespace: `default`)
  - `dashboard-tls` (namespace: `kubernetes-dashboard`)
  - `dagster-tls` (namespace: `dagster`)
- ArgoCD will deploy:
  - **nginx-demo** (`nginx-demo.localtest.me`)
  - **Kubernetes Dashboard** (`dashboard.localtest.me`)
  - **Dagster** (`dagster.localtest.me`)

---

## 📁 Repository Layout (this repo: `kubernetes`)

```bash
kubernetes/
├── kind/
│   └── kind-config.yaml                # Kind cluster configuration
├── argocd-ingress/
│   ├── argocd-ingress.yaml             # Ingress for ArgoCD (argocd.localtest.me)
│   └── kustomization.yaml
├── argocd-ingress/scripts/
│   └── generate-argocd-password.sh     # Helper for initial ArgoCD admin password
├── argocd-root-application/
│   ├── argocd-root.yaml                # ArgoCD Application pointing at argocd-platform repo
│   └── kustomization.yaml
├── kubernetes-dashboard/
│   ├── kubernetes-dashboard-ingress.yaml
│   ├── kustomization.yaml
│   └── scripts/
│       ├── generate-dashboard-token.sh
│       └── make-dashboard-kubeconfig.sh
├── certs/
│   ├── wildcard.localtest.me.pem
│   └── wildcard.localtest.me-key.pem
├── scripts/
│   ├── install-kind.sh
│   ├── install-nginx.sh
│   ├── install-agocd.sh
│   ├── create-argocd-tls-secret.sh
│   ├── create-nginx-demo-tls.sh
│   ├── create-dashboard-tls-secret.sh
│   ├── create-dagster-tls.sh
│   └── decode-secret.sh                # helper function
└── README.md                           # This file
```

The other two repos used by this setup are:

- **`argocd-platform`** – contains ArgoCD `Application` CRs:
  - `nginx-demo-app.yaml` → deploys `examples/nginx-demo`
  - `kubernetes-dashboard-app.yaml` → deploys dashboard + ingress
  - `dagster-app.yaml` → deploys Dagster via Helm into `dagster` namespace
- **`examples`** – contains actual workloads:
  - `nginx-demo/` (Deployment, Service, Ingress)
  - `dagster/` (Dockerfile + example code)

---

## 🧩 End-to-End Setup: Detailed Steps

All commands below assume you are in the **`kubernetes`** repo root unless noted.

---

### 1️⃣ Install Kind Cluster (from `kubernetes/scripts`)

Create or reuse the local Kind cluster:

```bash
cd kubernetes

./scripts/install-kind.sh
```

The script (`scripts/install-kind.sh`) does the following:

- Uses `kind/kind-config.yaml`.
- Checks if a cluster named `kind` already exists:
  - If it exists, it logs and exits.
  - If not, it runs:

    ```bash
    kind create cluster --name "kind" --config "kind/kind-config.yaml"
    ```

- Runs `kubectl cluster-info` at the end.

You can verify:

```bash
kubectl get nodes
kubectl get pods -A
```

---

### 2️⃣ Install NGINX Ingress (from `kubernetes/scripts`)

NGINX Ingress is installed directly from the **official upstream manifest**.  
**No TLS is configured for the `ingress-nginx` namespace itself** – TLS is only used for app ingresses.

From `kubernetes` repo root:

```bash
./scripts/install-nginx.sh
```

The script (`scripts/install-nginx.sh`) does roughly:

```bash
NGINX_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/kind/deploy.yaml"

echo "[nginx] Installing NGINX Ingress Controller..."
kubectl apply -f "${NGINX_MANIFEST_URL}"

kubectl wait --namespace ingress-nginx   --for=condition=Ready pod   --selector=app.kubernetes.io/component=controller   --timeout=180s
```

Check status:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc  -n ingress-nginx
```

At this point you have:

- A working Kind cluster.
- NGINX Ingress Controller running in `ingress-nginx` namespace.
- No TLS secrets created yet – those come later for individual apps.

---

### 3️⃣ Install ArgoCD & Create `argocd-tls` Secret

#### 3.1 Install ArgoCD (from `kubernetes/scripts`)

From the `kubernetes` repo root:

```bash
./scripts/install-agocd.sh
```

The script (`scripts/install-agocd.sh`) effectively does:

```bash
NAMESPACE="argocd"
ARGO_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

kubectl apply -n "${NAMESPACE}" -f "${ARGO_MANIFEST_URL}"

kubectl wait -n "${NAMESPACE}"   --for=condition=Ready pod   --selector=app.kubernetes.io/part-of=argocd   --timeout=300s

# Then applies local kustomization (ingress etc.)
kubectl apply -k argocd
```

Verify:

```bash
kubectl get pods -n argocd
```

#### 3.2 Create the `argocd-tls` Secret (from `kubernetes/scripts`)

ArgoCD ingress (in `argocd-ingress/argocd-ingress.yaml`) expects a TLS secret named **`argocd-tls`** in the `argocd` namespace:

```yaml
tls:
  - hosts:
      - argocd.localtest.me
    secretName: argocd-tls
```

From the `kubernetes` repo:

```bash
cd kubernetes/scripts

./create-argocd-tls-secret.sh
```

`create-argocd-tls-secret.sh` uses:

- Namespace: `argocd`
- Secret: `argocd-tls`
- Certificate: `../certs/wildcard.localtest.me.pem`
- Key: `../certs/wildcard.localtest.me-key.pem`

and runs:

```bash
kubectl create secret tls "argocd-tls"   -n "argocd"   --cert="../certs/wildcard.localtest.me.pem"   --key="../certs/wildcard.localtest.me-key.pem"   --dry-run=client -o yaml | kubectl apply -f -
```

Verify:

```bash
kubectl -n argocd get secret argocd-tls
```

#### 3.3 Apply ArgoCD Ingress

From the `kubernetes` repo root:

```bash
kubectl apply -k argocd-ingress
```

This creates an HTTPS ingress for `argocd.localtest.me` using `argocd-tls`.

Optional helper to get the initial ArgoCD admin password:

```bash
kubernetes/argocd-ingress/scripts/generate-argocd-password.sh
```

---

### 4️⃣ Deploy Apps via ArgoCD & Create App TLS Secrets

Once ArgoCD is up, it is bootstrapped using a **root Application** defined in `argocd-root-application/argocd-root.yaml`.

#### 4.1 Bootstrap the ArgoCD Root Application

`argocd-root-application/argocd-root.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/anandkpai/argocd-platform.git
    targetRevision: main
    path: apps
    directory:
      recurse: false
      include: "*-app.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

Apply it via Kustomize:

```bash
cd kubernetes

kubectl apply -k argocd-root-application
```

ArgoCD will then manage the apps from the **`argocd-platform`** repo:

- `nginx-demo` (`nginx-demo-app.yaml`)
- `kubernetes-dashboard` (`kubernetes-dashboard-app.yaml`)
- `dagster` (`dagster-app.yaml`)

You can inspect in ArgoCD UI (`https://argocd.localtest.me`) or via CLI:

```bash
argocd app list
```

---

### 4.2 Create TLS Secret for `nginx-demo` (from `kubernetes/scripts`)

The NGINX demo application ingress (from `examples/nginx-demo/nginx-demo-ingress.yaml`) expects `nginx-demo-tls` in the **`default`** namespace:

```yaml
tls:
  - hosts:
      - nginx-demo.localtest.me
    secretName: nginx-demo-tls
```

Create the secret using the helper script:

```bash
cd kubernetes/scripts

./create-nginx-demo-tls.sh
```

The script (`create-nginx-demo-tls.sh`) runs:

```bash
kubectl -n default create secret tls nginx-demo-tls   --cert=../certs/wildcard.localtest.me.pem   --key=../certs/wildcard.localtest.me-key.pem
```

Verify:

```bash
kubectl -n default get secret nginx-demo-tls
```

Once the ArgoCD app `nginx-demo` syncs, you should have:

- Deployment + Service in `default` namespace
- Ingress `nginx-demo.localtest.me` terminating at `nginx-demo-tls`

---

### 4.3 Create TLS Secret for Kubernetes Dashboard (from `kubernetes/scripts`)

The Dashboard ingress (`kubernetes/kubernetes-dashboard/kubernetes-dashboard-ingress.yaml`) expects a secret named **`dashboard-tls`**:

```yaml
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - dashboard.localtest.me
      secretName: dashboard-tls
  rules:
    - host: dashboard.localtest.me
      ...
```

Create/update the secret:

```bash
cd kubernetes/scripts

./create-dashboard-tls-secret.sh
```

`create-dashboard-tls-secret.sh`:

- Namespace: `kubernetes-dashboard`
- Secret: `dashboard-tls`
- Cert: `../certs/wildcard.localtest.me.pem`
- Key: `../certs/wildcard.localtest.me-key.pem`
- Uses `--dry-run=client -o yaml | kubectl apply -f -` for idempotency.

Verify:

```bash
kubectl -n kubernetes-dashboard get secret dashboard-tls
```

The Dashboard deployment + RBAC + ingress are created via:

- `kubernetes-dashboard/kustomization.yaml` (applied by `install-kubernetes-dashboard.sh` and/or ArgoCD app depending on how you run it)
- `argocd-platform/apps/kubernetes-dashboard-app.yaml` (GitOps control)

Helper utilities:

- `kubernetes/kubernetes-dashboard/scripts/generate-dashboard-token.sh`
- `kubernetes/kubernetes-dashboard/scripts/make-dashboard-kubeconfig.sh`

---

### 4.4 Create TLS Secret for Dagster (from `kubernetes/scripts`)

The Dagster ingress (`argocd-platform/apps/dagster/templates/dagster-ingress.yaml`) expects a secret **`dagster-tls`** in the `dagster` namespace:

```yaml
tls:
  - hosts:
      - dagster.localtest.me
    secretName: dagster-tls
```

The helper script is `scripts/create-dagster-tls.sh`:

```bash
cd kubernetes/certs

../scripts/create-dagster-tls.sh
```

The script content:

```bash
kubectl create secret tls dagster-tls   --cert=wildcard.localtest.me.pem   --key=wildcard.localtest.me-key.pem   -n dagster
```

Note the key difference from other scripts:

- It expects `wildcard.localtest.me.pem` and `wildcard.localtest.me-key.pem` in the **current working directory**, not via `../certs/...`.
- That’s why you typically run it from the `certs` directory (e.g. `cd kubernetes/certs && ../scripts/create-dagster-tls.sh`).

Verify:

```bash
kubectl -n dagster get secret dagster-tls
```

After ArgoCD syncs `dagster-app.yaml`, you’ll have:

- Dagster namespace
- Dagit webserver
- Daemon, etc.
- Ingress at `https://dagster.localtest.me` using `dagster-tls`.

---

## ✅ Final State Checklist

If everything worked, you should have:

- **Cluster**
  - A Kind cluster named `kind`.
  - NGINX ingress controller running in `ingress-nginx`.

- **ArgoCD**
  - ArgoCD installed in `argocd` namespace via upstream manifests.
  - `argocd-tls` secret present.
  - Ingress at `argocd.localtest.me`.

- **Apps (via ArgoCD / argocd-platform)**
  - `nginx-demo` in `default` namespace
    - TLS secret: `nginx-demo-tls`
    - Host: `nginx-demo.localtest.me`
  - `kubernetes-dashboard` in `kubernetes-dashboard` namespace
    - TLS secret: `dashboard-tls`
    - Host: `dashboard.localtest.me`
  - `dagster` in `dagster` namespace
    - TLS secret: `dagster-tls`
    - Host: `dagster.localtest.me`

- **Helpers**
  - Scripts to generate dashboard tokens and kubeconfig.
  - Script to inspect TLS secrets: `scripts/tls-info-or-create.sh`.

---

## 🧹 Teardown

To remove everything:

```bash
kind delete cluster
```

This deletes the entire Kind cluster and all associated resources.

---

## 📌 Notes

- This entire setup is intended for **local development and experimentation**.
- TLS currently relies on a **wildcard.localtest.me** certificate and key placed under `certs/`.
- Secrets for each ingress are created via explicit helper scripts so you can:
  - Rotate certificates centrally,
  - Recreate secrets cleanly,
  - Inspect TLS details easily via `tls-info-or-create.sh`.

