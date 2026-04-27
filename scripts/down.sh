#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib.sh"

require_cmd kind
require_cmd kubectl
require_cmd helm

CLUSTER_NAME="coursework-stand"

log_msg "Removing Helm releases if present..."
helm -n vault uninstall vault >/dev/null 2>&1 || true
helm -n postgres uninstall postgres >/dev/null 2>&1 || true

log_msg "Removing namespaces..."
kubectl delete ns vault --ignore-not-found >/dev/null 2>&1 || true
kubectl delete ns postgres --ignore-not-found >/dev/null 2>&1 || true
kubectl delete ns demo --ignore-not-found >/dev/null 2>&1 || true

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  log_msg "Deleting kind cluster '$CLUSTER_NAME'..."
  kind delete cluster --name "$CLUSTER_NAME"
else
  log_msg "Cluster '$CLUSTER_NAME' is not present."
fi

log_msg "Teardown complete."

