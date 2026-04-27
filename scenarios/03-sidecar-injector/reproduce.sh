#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kubectl

RUN_DIR="$(make_run_dir "03-sidecar-injector")"
LOG_FILE="$RUN_DIR/console.log"

log_msg "Scenario 03 started" | tee -a "$LOG_FILE"

# Ensure demo namespace and service account exist
kubectl get ns demo >/dev/null 2>&1 || kubectl create ns demo
kubectl -n demo get sa app-sa >/dev/null 2>&1 || kubectl -n demo create sa app-sa

# Deploy the Pod
kubectl apply -f "$ROOT/scenarios/02-dynamic-short-lived/app-deployment.yaml" | tee -a "$LOG_FILE"

log_msg "Waiting for Pod to be Ready (up to 120s)..." | tee -a "$LOG_FILE"
kubectl -n demo wait --for=condition=Ready pod -l app=demo-app --timeout=120s | tee -a "$LOG_FILE"

# Show: secret IS in the mounted file
log_msg "--- /vault/secrets/db content ---" | tee -a "$LOG_FILE"
kubectl -n demo exec deploy/demo-app -c app -- cat /vault/secrets/db 2>&1 | tee -a "$LOG_FILE"

# Show: secret is NOT in environment variables
log_msg "--- env vars (grep for sensitive values) ---" | tee -a "$LOG_FILE"
kubectl -n demo exec deploy/demo-app -c app -- \
  sh -c 'env | grep -iE "password|token|secret|database|postgres" || echo "(no secret env vars found)"' \
  2>&1 | tee -a "$LOG_FILE"

# Show: Vault annotations on the Pod
log_msg "--- Vault annotations ---" | tee -a "$LOG_FILE"
kubectl -n demo get pod -l app=demo-app -o jsonpath='{.items[0].metadata.annotations}' \
  2>&1 | tee -a "$LOG_FILE"

log_msg "Scenario 03 completed" | tee -a "$LOG_FILE"

# Cleanup
kubectl -n demo delete deployment demo-app --ignore-not-found | tee -a "$LOG_FILE"
