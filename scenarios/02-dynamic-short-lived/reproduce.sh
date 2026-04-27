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

RUN_DIR="$(make_run_dir "02-dynamic-short-lived")"
LOG_FILE="$RUN_DIR/console.log"

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
export VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN:-}"

if [[ -z "$VAULT_TOKEN" ]]; then
  echo "ERROR: VAULT_DEV_ROOT_TOKEN missing in .env.local." | tee -a "$LOG_FILE"
  exit 1
fi

log_msg "Scenario 02 started" | tee -a "$LOG_FILE"
screenshot "02-before" "$RUN_DIR" || true

RESP_JSON="$(vault read -format=json database/creds/readonly 2>>"$LOG_FILE")" || {
  echo "ERROR: Cannot read dynamic creds. Run bash vault/enable-db-engine.sh first." | tee -a "$LOG_FILE"
  exit 1
}

if command -v py >/dev/null 2>&1 && py -3 -V >/dev/null 2>&1; then
  PY_CMD=(py -3)
elif command -v python3 >/dev/null 2>&1; then
  PY_CMD=(python3)
elif command -v python >/dev/null 2>&1 && python -V >/dev/null 2>&1; then
  PY_CMD=(python)
else
  echo "ERROR: no usable python runtime found for JSON parsing." | tee -a "$LOG_FILE"
  exit 1
fi

"${PY_CMD[@]}" - <<'PY' "$RESP_JSON" "$LOG_FILE"
import json,sys
resp=json.loads(sys.argv[1])
log=sys.argv[2]
lease=resp.get("lease_duration")
username=resp.get("data",{}).get("username")
with open(log,"a",encoding="utf-8") as f:
    f.write(f"dynamic_username={username}\n")
    f.write(f"lease_duration_seconds={lease}\n")
print(f"dynamic_username={username}")
print(f"lease_duration_seconds={lease}")
PY

screenshot "02-dynamic-creds" "$RUN_DIR" || true
log_msg "Scenario 02 completed" | tee -a "$LOG_FILE"

