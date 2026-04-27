#!/usr/bin/env bash
# Simulates a naive GitHub Actions CI step that leaks secrets into stdout logs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"

RUN_DIR="$(make_run_dir "01-ci-log-simulate")"
LOG_FILE="$RUN_DIR/console.log"

# Create the same static.env as scenario 01
cat >"$RUN_DIR/static.env" <<'EOF'
DATABASE_URL=postgresql://app:hardcoded-password@db.internal:5432/appdb
API_TOKEN=hardcoded-token-value
EOF

log_msg "##[group]Run: Deploy to staging" | tee -a "$LOG_FILE"
log_msg "Loading environment configuration from static.env..." | tee -a "$LOG_FILE"

# shellcheck disable=SC1090
source "$RUN_DIR/static.env"

# Simulate a common CI anti-pattern: echoing env vars for "debugging"
log_msg "Connecting to database: $DATABASE_URL" | tee -a "$LOG_FILE"
log_msg "Using API token: $API_TOKEN" | tee -a "$LOG_FILE"
log_msg "Deploy step completed successfully." | tee -a "$LOG_FILE"
log_msg "##[endgroup]" | tee -a "$LOG_FILE"

screenshot "01-ci-log-leak" "$RUN_DIR" || true

echo ""
echo "=== CI log simulation complete ==="
cat "$LOG_FILE"
