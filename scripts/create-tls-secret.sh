#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --namespace <ns> --secret-name <name> --cert <path> --key <path> [--overwrite]

Creates or updates a TLS secret in the given namespace.

Arguments:
  --namespace     Kubernetes namespace
  --secret-name   Name of the TLS secret
  --cert          Path to the certificate file (PEM)
  --key           Path to the private key file (PEM)
  --overwrite     If set, always apply (kubectl apply) instead of failing when secret exists
EOF
  exit 1
}

NAMESPACE=""
SECRET_NAME=""
CERT_FILE=""
KEY_FILE=""
OVERWRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"; shift 2 ;;
    --secret-name)
      SECRET_NAME="$2"; shift 2 ;;
    --cert)
      CERT_FILE="$2"; shift 2 ;;
    --key)
      KEY_FILE="$2"; shift 2 ;;
    --overwrite)
      OVERWRITE=true; shift 1 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown argument: $1"
      usage ;;
  esac
done

if [[ -z "$NAMESPACE" || -z "$SECRET_NAME" || -z "$CERT_FILE" || -z "$KEY_FILE" ]]; then
  echo "ERROR: Missing required arguments."
  usage
fi

if [[ ! -f "$CERT_FILE" ]]; then
  echo "ERROR: Certificate file not found: $CERT_FILE"
  exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
  echo "ERROR: Key file not found: $KEY_FILE"
  exit 1
fi

echo "[tls] Namespace:   $NAMESPACE"
echo "[tls] Secret:      $SECRET_NAME"
echo "[tls] Certificate: $CERT_FILE"
echo "[tls] Key:         $KEY_FILE"

if kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
  if ! $OVERWRITE; then
    echo "[tls] Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'. Use --overwrite to update."
    exit 0
  fi
  echo "[tls] Updating existing secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
else
  echo "[tls] Creating new secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
fi

kubectl create secret tls "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --cert="$CERT_FILE" \
  --key="$KEY_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[tls] Secret '$SECRET_NAME' is now present in namespace '$NAMESPACE'."
kubectl -n "$NAMESPACE" get secret "$SECRET_NAME"
