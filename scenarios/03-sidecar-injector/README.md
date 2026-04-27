# Scenario 03: Vault Agent Sidecar Injector

Deploys a real Kubernetes Pod with Vault Agent Sidecar Injector.
Demonstrates:
1. Dynamic DB credentials mounted at /vault/secrets/db (not in env vars)
2. env vars contain NO secret values
3. Vault annotations visible on the Pod

Prerequisites: vault/enable-k8s-auth.sh, vault/enable-db-engine.sh
Run: bash scenarios/03-sidecar-injector/reproduce.sh
