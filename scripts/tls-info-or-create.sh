#!/bin/bash

set -e

# --- Parse arguments ---
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --tls-secret-name)
      TLS_SECRET_NAME="$2"
      shift
      ;;
    --namespace)
      NAMESPACE="$2"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
  shift
done

# --- Validate required inputs ---
if [[ -z "$TLS_SECRET_NAME" || -z "$NAMESPACE" ]]; then
  echo "Usage: $0 --tls-secret-name <name> --namespace <namespace>"
  exit 1
fi

echo "🔍 Checking TLS secret '$TLS_SECRET_NAME' in namespace '$NAMESPACE' ..."
echo

# --- Check if secret exists ---
if kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✔ TLS secret already exists."
else
    echo "❌ Secret not found."
    echo "🛠 Creating new TLS secret '$TLS_SECRET_NAME' ..."

    TMP_CERT="/tmp/${TLS_SECRET_NAME}.crt"
    TMP_KEY="/tmp/${TLS_SECRET_NAME}.key"

    # Generate a new private key + self-signed cert (1 year)
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$TMP_KEY" \
        -out "$TMP_CERT" \
        -subj "/CN=${TLS_SECRET_NAME}.local"

    # Create k8s TLS secret
    kubectl create secret tls "$TLS_SECRET_NAME" \
        --cert="$TMP_CERT" \
        --key="$TMP_KEY" \
        -n "$NAMESPACE"

    echo "✔ Secret created."
fi

echo
echo "📄 Secret Summary:"
kubectl describe secret "$TLS_SECRET_NAME" -n "$NAMESPACE"

echo
echo "🔐 Extracting certificate..."
kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls.crt

echo "🔐 Extracting private key..."
kubectl get secret "$TLS_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/tls.key

echo
echo "📜 Certificate Details:"
openssl x509 -in /tmp/tls.crt -text -noout

echo
echo "🔏 Key Type:"
openssl pkey -in /tmp/tls.key -text -noout | head -n 20

echo
echo "✔ Done."
