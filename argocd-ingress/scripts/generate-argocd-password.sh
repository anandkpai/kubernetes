#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="argocd"
SECRET_NAME="argocd-initial-admin-secret"

echo "Checking if namespace '${NAMESPACE}' exists..."
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Namespace '${NAMESPACE}' does NOT exist."
    echo "Make sure ArgoCD is installed (e.g. via ./install-agocd.sh)."
    exit 1
fi

echo "Checking if secret '${SECRET_NAME}' exists in namespace '${NAMESPACE}'..."
if ! kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" >/dev/null 2>&1; then
    echo "ERROR: Secret '${SECRET_NAME}' does NOT exist in namespace '${NAMESPACE}'."
    echo "This usually means:"
    echo "  - ArgoCD is not fully installed, or"
    echo "  - The initial admin secret has already been removed/rotated."
    exit 1
fi

echo "Retrieving ArgoCD admin password..."
PASSWORD=$(
  kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" \
    -o jsonpath="{.data.password}" | base64 -d
)

echo ""
echo "=============================================="
echo " ArgoCD Admin Credentials"
echo "=============================================="
echo "  URL: https://argocd.localtest.me:8443"
echo "  User: admin"
echo "  Pass: ${PASSWORD}"
echo "=============================================="
echo ""
echo "Paste these into the ArgoCD login page."
