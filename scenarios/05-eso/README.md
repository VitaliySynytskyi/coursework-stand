# Scenario 05: External Secrets Operator (GitOps Integration)

Demonstrates GitOps-style secret management: ESO syncs secrets from Vault KV
to native Kubernetes Secret objects automatically.

Prerequisites: vault/bootstrap.sh (creates kv/app/config)
Run: bash scenarios/05-eso/reproduce.sh
