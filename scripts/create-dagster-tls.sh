#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/create-tls-secret.sh" \
  --namespace dagster \
  --secret-name dagster-tls \
  --cert "${SCRIPT_DIR}/../certs/wildcard.localtest.me.pem" \
  --key  "${SCRIPT_DIR}/../certs/wildcard.localtest.me-key.pem" \
   "$@"
