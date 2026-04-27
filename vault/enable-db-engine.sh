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

if [[ -z "${VAULT_DEV_ROOT_TOKEN:-}" || -z "${POSTGRES_PASSWORD:-}" ]]; then
  echo "ERROR: VAULT_DEV_ROOT_TOKEN or POSTGRES_PASSWORD missing in .env.local" >&2
  exit 1
fi

PF_VAULT=""
cleanup() {
  if [[ -n "$PF_VAULT" ]]; then kill "$PF_VAULT" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

kubectl -n vault port-forward svc/vault 8200:8200 >/dev/null 2>&1 &
PF_VAULT=$!
sleep 5

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="$VAULT_DEV_ROOT_TOKEN"

vault secrets list | grep -q "^database/" || vault secrets enable database
vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles=readonly \
  connection_url="postgresql://{{username}}:{{password}}@postgres-postgresql.postgres.svc.cluster.local:5432/appdb?sslmode=disable" \
  username=postgres \
  password="$POSTGRES_PASSWORD"

vault write database/roles/readonly \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE appdb TO \"{{name}}\";" \
  default_ttl=1m \
  max_ttl=5m

echo "Database secrets engine enabled."

