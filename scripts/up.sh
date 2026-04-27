#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib.sh"

for c in docker kubectl helm kind python; do
  require_cmd "$c"
done

CLUSTER_NAME="coursework-stand"

log_msg "Ensuring kind cluster '$CLUSTER_NAME' exists..."
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT/kind/cluster-config.yaml"
else
  log_msg "Cluster already exists."
fi

helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo update >/dev/null

kubectl get ns vault >/dev/null 2>&1 || kubectl create ns vault
kubectl get ns postgres >/dev/null 2>&1 || kubectl create ns postgres

if [[ ! -f "$ROOT/.env.local" ]]; then
  log_msg "Generating .env.local with local-only secrets."
  POSTGRES_PASSWORD="$(random_secret)"
  VAULT_DEV_ROOT_TOKEN="$(random_secret)"
  cat >"$ROOT/.env.local" <<EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
VAULT_DEV_ROOT_TOKEN=$VAULT_DEV_ROOT_TOKEN
EOF
fi

# shellcheck disable=SC1091
source "$ROOT/.env.local"

kubectl -n postgres create secret generic postgres-auth \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

log_msg "Installing PostgreSQL chart..."
helm upgrade --install postgres bitnami/postgresql \
  -n postgres \
  -f "$ROOT/helm/postgres-values.yaml" \
  --wait

log_msg "Installing Vault chart..."
helm upgrade --install vault hashicorp/vault \
  -n vault \
  -f "$ROOT/helm/vault-values.yaml" \
  --set "server.dev.devRootToken=${VAULT_DEV_ROOT_TOKEN}" \
  --wait

log_msg "Running smoke test..."
bash "$ROOT/scripts/smoke-test.sh"

log_msg "Environment is ready."

