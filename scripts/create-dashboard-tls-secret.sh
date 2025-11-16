#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kubernetes-dashboard"
CERT="../certs/wildcard.localtest.me.pem"
KEY="../certs/wildcard.localtest.me-key.pem"
SECRET_NAME="dashboard-tls"

if [[ ! -f "$CERT" ]]; then
  echo "❌ Certificate not found: $CERT"
  exit 1
fi

if [[ ! -f "$KEY" ]]; then
  echo "❌ Key not found: $KEY"
  exit 1
fi

echo "🔐 Creating/updating TLS secret '$SECRET_NAME' in namespace '$NAMESPACE'"

kubectl -n "$NAMESPACE" create secret tls "$SECRET_NAME" \
  --cert="$CERT" \
  --key="$KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret '$SECRET_NAME' is now present in namespace '$NAMESPACE'"
