#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"

RUN_DIR="$(make_run_dir "01-static-secret-leak")"
LOG_FILE="$RUN_DIR/console.log"

log_msg "Scenario 01 started" | tee -a "$LOG_FILE"
screenshot "01-before" "$RUN_DIR" || true

cat >"$RUN_DIR/static.env" <<'EOF'
DATABASE_URL=postgresql://app:hardcoded-password@db.internal:5432/appdb
API_TOKEN=hardcoded-token-value
EOF

log_msg "Scanning static file for secrets (intentional anti-pattern)." | tee -a "$LOG_FILE"
grep -nE "PASSWORD|TOKEN|DATABASE_URL" "$RUN_DIR/static.env" | tee -a "$LOG_FILE"

screenshot "01-leak-detected" "$RUN_DIR" || true
log_msg "Scenario 01 completed" | tee -a "$LOG_FILE"

