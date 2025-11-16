#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME="kind"
KIND_CONFIG="kind/kind-config.yaml"
echo "[kind] Checking for existing cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[kind] Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
  exit 0
fi
echo "[kind] Creating cluster '${CLUSTER_NAME}' using config '${KIND_CONFIG}'..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
echo "[kind] Cluster '${CLUSTER_NAME}' created."
kubectl cluster-info
