#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kubectl
require_cmd vault

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

vault secrets list | grep -q "^kv/" || vault secrets enable -path=kv kv-v2
vault kv put kv/app/config message="coursework-stand bootstrap complete"
vault policy write app-readonly "$ROOT/vault/policies/app-readonly.hcl"

echo "Vault bootstrap complete."

