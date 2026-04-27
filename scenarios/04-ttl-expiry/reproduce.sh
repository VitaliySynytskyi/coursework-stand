#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kubectl
require_cmd vault

if [[ ! -f "$ROOT/.env.local" ]]; then
  echo "ERROR: .env.local not found. Run bash scripts/up.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$ROOT/.env.local"

RUN_DIR="$(make_run_dir "04-ttl-expiry")"
LOG_FILE="$RUN_DIR/console.log"

PF_VAULT_PID=""
cleanup() {
  [[ -n "$PF_VAULT_PID" ]] && kill "$PF_VAULT_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl -n vault port-forward svc/vault 8200:8200 >/dev/null 2>&1 &
PF_VAULT_PID=$!
sleep 4

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN}"

log_msg "Scenario 04 started — TTL expiry proof" | tee -a "$LOG_FILE"

# Obtain dynamic credentials
RESP_JSON="$(vault read -format=json database/creds/readonly)"

# Parse with python (try py, python, python3)
parse_json() {
  local field="$1"
  local json="$2"
  echo "$json" | py -3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['$field'])" 2>/dev/null \
    || echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['$field'])" 2>/dev/null \
    || echo "$json" | python -c "import json,sys; d=json.load(sys.stdin); print(d['data']['$field'])" 2>/dev/null
}

DYN_USER="$(parse_json username "$RESP_JSON")"
DYN_PASS="$(parse_json password "$RESP_JSON")"

log_msg "Obtained credentials: username=$DYN_USER  TTL=60s" | tee -a "$LOG_FILE"

# Step 1: Connect immediately — must succeed
log_msg "=== Attempting connection BEFORE TTL expiry ===" | tee -a "$LOG_FILE"
if kubectl -n postgres exec postgres-postgresql-0 -- \
     env PGPASSWORD="$DYN_PASS" psql -U "$DYN_USER" -d appdb -c "SELECT 'TTL-test-ok' AS result;" \
     2>&1 | tee -a "$LOG_FILE"; then
  log_msg "RESULT: Connection SUCCEEDED (expected)" | tee -a "$LOG_FILE"
else
  log_msg "WARN: Connection failed before TTL — check DB engine config" | tee -a "$LOG_FILE"
fi

# Step 2: Wait for TTL to expire
log_msg "=== Waiting 65 seconds for TTL=60s to expire ===" | tee -a "$LOG_FILE"
for s in 10 20 30 40 50 60 65; do
  sleep 5
  log_msg "  ...${s}s elapsed" | tee -a "$LOG_FILE"
done

# Step 3: Connect after TTL — must fail
log_msg "=== Attempting connection AFTER TTL expiry ===" | tee -a "$LOG_FILE"
if kubectl -n postgres exec postgres-postgresql-0 -- \
     env PGPASSWORD="$DYN_PASS" psql -U "$DYN_USER" -d appdb -c "SELECT 1;" \
     2>&1 | tee -a "$LOG_FILE"; then
  log_msg "UNEXPECTED: Connection still succeeded after TTL!" | tee -a "$LOG_FILE"
else
  log_msg "RESULT: Connection FAILED — role revoked by Vault (expected)" | tee -a "$LOG_FILE"
fi

log_msg "Scenario 04 completed" | tee -a "$LOG_FILE"
