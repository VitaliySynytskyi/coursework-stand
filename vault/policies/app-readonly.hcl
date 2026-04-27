path "database/creds/readonly" {
  capabilities = ["read"]
}

path "kv/data/app/*" {
  capabilities = ["read"]
}

