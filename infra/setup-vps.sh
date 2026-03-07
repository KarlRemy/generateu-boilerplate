#!/usr/bin/env bash
# =============================================================================
# setup-vps.sh - One-time VPS initialisation (idempotent)
#
# Target host : 91.134.132.141  (karl-remy.fr)
# Reverse proxy: Caddy (TLS automatique via ACME/Let's Encrypt)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/registry.sh"

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
info "Updating system packages ..."
apt-get update -y && apt-get upgrade -y
success "System packages up to date."

# ---------------------------------------------------------------------------
# 2. Install Docker (skip if already present)
# ---------------------------------------------------------------------------
if command -v docker &>/dev/null; then
    success "Docker already installed: $(docker --version)"
else
    info "Installing Docker ..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    success "Docker installed."
fi

# ---------------------------------------------------------------------------
# 3. Install Caddy from official repository
# ---------------------------------------------------------------------------
if command -v caddy &>/dev/null; then
    success "Caddy already installed: $(caddy version)"
else
    info "Installing Caddy ..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y
    apt-get install -y caddy
    success "Caddy installed."
fi

# ---------------------------------------------------------------------------
# 4. Install jq and GitHub CLI
# ---------------------------------------------------------------------------
if command -v jq &>/dev/null; then
    success "jq already installed."
else
    info "Installing jq ..."
    apt-get install -y jq
    success "jq installed."
fi

if command -v gh &>/dev/null; then
    success "GitHub CLI already installed."
else
    info "Installing GitHub CLI ..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null
    apt-get update -y
    apt-get install -y gh
    success "GitHub CLI installed."
fi

# ---------------------------------------------------------------------------
# 5. Create directory structure
# ---------------------------------------------------------------------------
info "Creating directory structure ..."
mkdir -p /opt/generateu/{shared,projects}
mkdir -p /opt/generateu/shared/caddy
mkdir -p /var/log/caddy
success "Directories ready."

# ---------------------------------------------------------------------------
# 6. Create Caddyfile (TLS automatique par Caddy)
# ---------------------------------------------------------------------------
info "Writing /etc/caddy/Caddyfile ..."
cat > /etc/caddy/Caddyfile <<'CADDYFILE'
{
    email karl@karl-remy.fr
}

# Import per-project configs
import /opt/generateu/shared/caddy/*.caddy
CADDYFILE
success "Caddyfile written."

systemctl enable caddy
systemctl restart caddy
success "Caddy enabled and started."

# ---------------------------------------------------------------------------
# 7. Shared services (PostgreSQL + Mailpit)
# ---------------------------------------------------------------------------
info "Starting shared services (PostgreSQL, Mailpit) ..."
if [[ ! -f /opt/generateu/shared/docker-compose.shared.yml ]]; then
    cp "${SCRIPT_DIR}/docker-compose.shared.yml" /opt/generateu/shared/docker-compose.shared.yml
fi
cd /opt/generateu/shared
docker compose -f docker-compose.shared.yml up -d
success "Shared services running."

# ---------------------------------------------------------------------------
# 8. Docker network
# ---------------------------------------------------------------------------
if docker network inspect generateu_network &>/dev/null; then
    success "Docker network 'generateu_network' already exists."
else
    info "Creating Docker network 'generateu_network' ..."
    docker network create generateu_network
    success "Docker network created."
fi

docker network connect generateu_network generateu_postgres 2>/dev/null || true
docker network connect generateu_network generateu_mailpit 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. Firewall
# ---------------------------------------------------------------------------
info "Configuring firewall ..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
success "Firewall configured (SSH, HTTP, HTTPS)."

# ---------------------------------------------------------------------------
# 10. Initialise project registry
# ---------------------------------------------------------------------------
registry_init

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${RESET}"
echo -e "${GREEN}  VPS setup complete!${RESET}"
echo -e "${GREEN}============================================${RESET}"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo "1. Add DNS records:"
echo "     A    *.karl-remy.fr  ->  91.134.132.141"
echo "     A    karl-remy.fr    ->  91.134.132.141"
echo ""
echo "2. Authenticate GitHub CLI:"
echo "     gh auth login"
echo ""
echo "Caddy gerera automatiquement les certificats SSL via Let's Encrypt."
echo ""
