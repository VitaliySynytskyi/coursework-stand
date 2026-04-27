#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib.sh"
require_cmd helm

helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

if helm -n external-secrets status external-secrets >/dev/null 2>&1; then
  echo "ESO already installed, skipping."
else
  kubectl get ns external-secrets >/dev/null 2>&1 || kubectl create ns external-secrets
  helm install external-secrets external-secrets/external-secrets \
    -n external-secrets \
    --set installCRDs=true \
    --wait
  echo "ESO installed."
fi
