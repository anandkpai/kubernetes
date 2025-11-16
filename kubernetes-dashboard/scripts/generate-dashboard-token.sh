#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kubernetes-dashboard"
SERVICE_ACCOUNT="admin-user"

echo "Checking if service account '${SERVICE_ACCOUNT}' exists in namespace '${NAMESPACE}'..."
if ! kubectl -n "${NAMESPACE}" get sa "${SERVICE_ACCOUNT}" >/dev/null 2>&1; then
    echo "ERROR: Service account '${SERVICE_ACCOUNT}' does NOT exist in '${NAMESPACE}'."
    echo "Make sure your dashboard kustomization has been applied:"
    echo "    kubectl apply -k kubernetes-dashboard"
    exit 1
fi

echo "Generating token..."
TOKEN=$(kubectl -n "${NAMESPACE}" create token "${SERVICE_ACCOUNT}")

echo ""
echo "=============================================="
echo " Kubernetes Dashboard Token"
echo "=============================================="
echo "${TOKEN}"
echo "=============================================="
echo ""
echo "Use this token at:"
echo "  https://dashboard.localtest.me:8443/#/login"
echo ""
