#!/usr/bin/env bash
set -euo pipefail
NAMESPACE="argocd"
ARGO_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"
kubectl apply -n "${NAMESPACE}" -f "${ARGO_MANIFEST_URL}"
kubectl wait -n "${NAMESPACE}" --for=condition=Ready pod --selector=app.kubernetes.io/part-of=argocd --timeout=300s
kubectl apply -k argocd
