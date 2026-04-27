#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib.sh"

for c in docker kubectl helm kind; do
  require_cmd "$c"
done

CLUSTER_NAME="coursework-stand"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "FAIL: kind cluster '$CLUSTER_NAME' not found. Run bash scripts/up.sh first." >&2
  exit 1
fi

kubectl cluster-info >/dev/null

kubectl -n postgres wait --for=condition=Ready pod -l app.kubernetes.io/name=postgresql --timeout=180s >/dev/null
kubectl -n vault wait --for=condition=Ready pod -l app.kubernetes.io/name=vault --timeout=180s >/dev/null

if [[ -f "$ROOT/.env.local" ]] && command -v vault >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$ROOT/.env.local"
  if [[ -n "${VAULT_DEV_ROOT_TOKEN:-}" ]]; then
    kubectl -n vault exec vault-0 -- sh -lc "VAULT_TOKEN='${VAULT_DEV_ROOT_TOKEN}' vault status >/dev/null"
  fi
fi

echo "SMOKE TEST: PASS"

