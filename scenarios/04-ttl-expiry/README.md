# Scenario 04: TTL Expiry Proof

Empirically proves that Vault-issued credentials are revoked after TTL=60s.

Steps:
1. Obtain dynamic PostgreSQL credentials from Vault
2. Connect immediately → SUCCESS
3. Wait 65 seconds
4. Connect with same credentials → FATAL: role does not exist

Prerequisites: vault/enable-db-engine.sh
Run: bash scenarios/04-ttl-expiry/reproduce.sh
