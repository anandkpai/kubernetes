#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
#  Configuration
# -------------------------------
NAMESPACE="argocd"
SECRET_NAME="argocd-tls"
CERT_DIR="certs"
CERT_FILE="${CERT_DIR}/wildcard.localtest.me.pem"
KEY_FILE="${CERT_DIR}/wildcard.localtest.me-key.pem"

OVERRIDE=false

# -------------------------------
#  Parse flags
# -------------------------------
for arg in "$@"; do
    case $arg in
        --override-existing)
            OVERRIDE=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--override-existing]"
            exit 1
            ;;
    esac
done

# -------------------------------
#  Detect working directory
# -------------------------------
echo "[argocd-tls] Current directory: $(pwd)"

if [[ ! -d "${CERT_DIR}" ]]; then
    echo "ERROR: Could not find '${CERT_DIR}/' directory in $(pwd)"
    echo "Run this script from the from the argocd directory."
    exit 1
fi

# -------------------------------
#  Validate cert files
# -------------------------------
if [[ ! -f "${CERT_FILE}" ]]; then
    echo "ERROR: Certificate file '${CERT_FILE}' not found."
    exit 1
fi

if [[ ! -f "${KEY_FILE}" ]]; then
    echo "ERROR: Key file '${KEY_FILE}' not found."
    exit 1
fi

# -------------------------------
#  Ensure namespace exists
# -------------------------------
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "[argocd-tls] Namespace '${NAMESPACE}' does not exist. Creating..."
    kubectl create namespace "${NAMESPACE}"
fi

# -------------------------------
#  Check existing secret
# -------------------------------
if kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" >/dev/null 2>&1; then
    echo "[argocd-tls] Secret '${SECRET_NAME}' already exists in namespace '${NAMESPACE}'."

    if [[ "${OVERRIDE}" == true ]]; then
        echo "[argocd-tls] --override-existing set. Recreating secret..."
    else
        echo "[argocd-tls] Leaving existing secret unchanged."
        exit 0
    fi
else
    echo "[argocd-tls] Secret '${SECRET_NAME}' does not exist. Creating..."
fi

# -------------------------------
#  Create / Update TLS secret
# -------------------------------
kubectl create secret tls "${SECRET_NAME}" \
    -n "${NAMESPACE}" \
    --cert="${CERT_FILE}" \
    --key="${KEY_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo
echo "[argocd-tls] Secret '${SECRET_NAME}' updated successfully."
kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}"
