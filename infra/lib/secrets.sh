#!/usr/bin/env bash
# =============================================================================
# secrets.sh - Cryptographic secret and password generation
# =============================================================================

# generate_secret [length]
#   Produce a hex-encoded random string (default 32 bytes = 64 hex chars).
generate_secret() {
    local length="${1:-32}"
    openssl rand -hex "$length"
}

# generate_password [length]
#   Produce a hex-encoded random password (default 16 bytes = 32 hex chars).
generate_password() {
    local length="${1:-16}"
    openssl rand -hex "$length"
}
