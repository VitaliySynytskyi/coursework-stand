#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kubectl
require_cmd helm

if [[ ! -f "$ROOT/.env.local" ]]; then
  echo "ERROR: .env.local not found." >&2; exit 1
fi
# shellcheck disable=SC1091
source "$ROOT/.env.local"

RUN_DIR="$(make_run_dir "05-eso")"
LOG_FILE="$RUN_DIR/console.log"

log_msg "Scenario 05 started — External Secrets Operator" | tee -a "$LOG_FILE"

bash "$(dirname "${BASH_SOURCE[0]}")/eso-install.sh" | tee -a "$LOG_FILE"

kubectl get ns demo >/dev/null 2>&1 || kubectl create ns demo

sed "s/VAULT_TOKEN_PLACEHOLDER/${VAULT_DEV_ROOT_TOKEN}/" \
  "$(dirname "${BASH_SOURCE[0]}")/vault-secret-store.yaml" \
  | kubectl apply -f - | tee -a "$LOG_FILE"

kubectl apply -f "$(dirname "${BASH_SOURCE[0]}")/external-secret.yaml" | tee -a "$LOG_FILE"

log_msg "Waiting for ExternalSecret to sync (up to 60s)..." | tee -a "$LOG_FILE"
for i in $(seq 1 12); do
  STATUS="$(kubectl -n demo get externalsecret app-config \
    -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo 'NotReady')"
  if [[ "$STATUS" == "SecretSynced" ]]; then
    log_msg "ExternalSecret status: $STATUS" | tee -a "$LOG_FILE"
    break
  fi
  sleep 5
  log_msg "  ...${i}x5s — status: $STATUS" | tee -a "$LOG_FILE"
done

log_msg "=== Synced Kubernetes Secret keys ===" | tee -a "$LOG_FILE"
kubectl -n demo get secret app-config -o jsonpath='{.data}' 2>&1 | tee -a "$LOG_FILE"

log_msg "=== ExternalSecret status ===" | tee -a "$LOG_FILE"
kubectl -n demo get externalsecret app-config 2>&1 | tee -a "$LOG_FILE"

log_msg "Scenario 05 completed" | tee -a "$LOG_FILE"
