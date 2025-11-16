#!/usr/bin/env bash
set -euo pipefail
NGINX_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/kind/deploy.yaml"
echo "[nginx] Installing NGINX Ingress Controller..."
kubectl apply -f "${NGINX_MANIFEST_URL}"
kubectl wait --namespace ingress-nginx --for=condition=Ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
