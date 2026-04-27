#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_windows_tool_paths() {
  local localapp
  if command -v cygpath >/dev/null 2>&1 && [[ -n "${LOCALAPPDATA:-}" ]]; then
    localapp="$(cygpath -u "$LOCALAPPDATA")"
  else
    localapp="/c/Users/${USERNAME:-$USER}/AppData/Local"
  fi

  local -a candidates=()
  shopt -s nullglob
  candidates+=("$localapp"/Microsoft/WinGet/Packages/Helm.Helm_*/windows-amd64)
  candidates+=("$localapp"/Microsoft/WinGet/Packages/Kubernetes.kind_*)
  candidates+=("$localapp"/Microsoft/WinGet/Packages/Hashicorp.Vault_*)
  shopt -u nullglob

  for dir in "${candidates[@]}"; do
    if [[ -d "$dir" ]]; then
      PATH="$dir:$PATH"
    fi
  done
  export PATH
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' not found in PATH." >&2
    return 1
  fi
}

log_msg() {
  local msg="$1"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg"
}

random_secret() {
  if command -v py >/dev/null 2>&1 && py -3 -V >/dev/null 2>&1; then
    py -3 - <<'PY'
import secrets, string
alphabet = string.ascii_letters + string.digits
print(''.join(secrets.choice(alphabet) for _ in range(24)))
PY
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets, string
alphabet = string.ascii_letters + string.digits
print(''.join(secrets.choice(alphabet) for _ in range(24)))
PY
  elif command -v python >/dev/null 2>&1 && python -V >/dev/null 2>&1; then
    python - <<'PY'
import secrets, string
alphabet = string.ascii_letters + string.digits
print(''.join(secrets.choice(alphabet) for _ in range(24)))
PY
  else
    echo "ERROR: python runtime not found (python/python3/py)." >&2
    return 1
  fi
}

make_run_dir() {
  local scenario="$1"
  local ts
  ts="$(date '+%Y-%m-%d-%H%M%S')"
  local dir="$ROOT_DIR/capture/runs/${ts}-${scenario}"
  mkdir -p "$dir"
  ln -sfn "$(basename "$dir")" "$ROOT_DIR/capture/runs/LATEST" 2>/dev/null || true
  printf '%s\n' "$dir"
}

screenshot() {
  local name="$1"
  local run_dir="$2"
  if command -v py >/dev/null 2>&1 && py -3 -V >/dev/null 2>&1; then
    py -3 "$ROOT_DIR/capture/take-screenshot.py" "$name" "$run_dir"
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT_DIR/capture/take-screenshot.py" "$name" "$run_dir"
  elif command -v python >/dev/null 2>&1 && python -V >/dev/null 2>&1; then
    python "$ROOT_DIR/capture/take-screenshot.py" "$name" "$run_dir"
  else
    echo "ERROR: python runtime not found for screenshot capture." >&2
    return 1
  fi
}

ensure_windows_tool_paths

