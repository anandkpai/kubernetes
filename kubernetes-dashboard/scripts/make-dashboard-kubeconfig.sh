#!/usr/bin/env bash

NAMESPACE="kubernetes-dashboard"
SA_NAME="admin-user"
SECRET_NAME="admin-user-token"

echo "Using SA: ${SA_NAME} in namespace: ${NAMESPACE}"

# Sanity check
kubectl -n "${NAMESPACE}" get sa "${SA_NAME}" >/dev/null 2>&1 || {
  echo "ServiceAccount ${SA_NAME} not found in ${NAMESPACE}"
  exit 1
}

kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" >/dev/null 2>&1 || {
  echo "Secret ${SECRET_NAME} not found in ${NAMESPACE}"
  echo "Did you run the 'kubectl apply -f - <<EOF ...' step to create it?"
  exit 1
}

echo "Waiting 5 seconds for token to be populated..."
sleep 5

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

CLUSTER_CA=$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl -n "${NAMESPACE}" get secret "${SECRET_NAME}" -o jsonpath='{.data.token}' | base64 -d)

OUT_FILE="dashboard-sa.kubeconfig"

cat <<EOF > "${OUT_FILE}"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${SA_NAME}
  name: ${SA_NAME}-context
current-context: ${SA_NAME}-context
users:
- name: ${SA_NAME}
  user:
    token: ${TOKEN}
EOF

echo "Wrote kubeconfig to ${OUT_FILE}"
echo "Use this file in the Dashboard login screen under 'Kubeconfig'."
