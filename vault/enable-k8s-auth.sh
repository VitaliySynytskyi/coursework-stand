#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kubectl
require_cmd vault
require_cmd base64

if [[ ! -f "$ROOT/.env.local" ]]; then
  echo "ERROR: .env.local not found. Run bash scripts/up.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/.env.local"

if [[ -z "${VAULT_DEV_ROOT_TOKEN:-}" ]]; then
  echo "ERROR: VAULT_DEV_ROOT_TOKEN missing in .env.local" >&2
  exit 1
fi

kubectl get ns demo >/dev/null 2>&1 || kubectl create ns demo
kubectl -n demo get sa app-sa >/dev/null 2>&1 || kubectl -n demo create sa app-sa

PF_PID=""
cleanup() {
  if [[ -n "$PF_PID" ]]; then
    kill "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

kubectl -n vault port-forward svc/vault 8200:8200 >/dev/null 2>&1 &
PF_PID=$!
sleep 4

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="$VAULT_DEV_ROOT_TOKEN"

KUBE_HOST="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')"
KUBE_CA_FILE="$(mktemp)"
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d >"$KUBE_CA_FILE"
TOKEN_REVIEW_JWT="$(kubectl -n demo create token app-sa)"

vault auth list | grep -q "^kubernetes/" || vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="$KUBE_HOST" token_reviewer_jwt="$TOKEN_REVIEW_JWT" kubernetes_ca_cert=@"$KUBE_CA_FILE"
vault write auth/kubernetes/role/app \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=demo \
  policies=app-readonly \
  ttl=1h

rm -f "$KUBE_CA_FILE"
echo "Kubernetes auth enabled."

