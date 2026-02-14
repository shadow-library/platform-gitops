# =============================================================================
# Vault Server Configuration
# =============================================================================
# File-backed storage for persistent local development.
# TLS is disabled — this is intended for local use only.
# =============================================================================

ui = true

# Use mlock to prevent secrets from being swapped to disk.
# Requires IPC_LOCK capability (set via cap_add in docker-compose).
disable_mlock = false

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://0.0.0.0:8200"
