#!/usr/bin/env bash
# =============================================================================
# setup-vps.sh - One-time VPS initialisation (idempotent)
#
# Target host : 91.134.132.141  (karl-remy.fr)
# Reverse proxy: Caddy (same stack as FrankenPHP)
# SSL          : Let's Encrypt wildcard via Certbot + OVH DNS plugin
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
# 4. Install Certbot with OVH DNS plugin (wildcard SSL)
# ---------------------------------------------------------------------------
if command -v certbot &>/dev/null; then
    success "Certbot already installed."
else
    info "Installing Certbot + OVH DNS plugin ..."
    apt-get install -y certbot python3-certbot-dns-ovh
    success "Certbot installed."
fi

# ---------------------------------------------------------------------------
# 5. Install jq and GitHub CLI
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
# 6. Create directory structure
# ---------------------------------------------------------------------------
info "Creating directory structure ..."
mkdir -p /opt/generateu/{shared,projects}
mkdir -p /opt/generateu/shared/caddy
mkdir -p /var/log/caddy
success "Directories ready."

# ---------------------------------------------------------------------------
# 7. Create Caddyfile
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

# Enable and start Caddy
systemctl enable caddy
systemctl restart caddy
success "Caddy enabled and started."

# ---------------------------------------------------------------------------
# 8. Shared services (PostgreSQL + Mailpit)
# ---------------------------------------------------------------------------
info "Starting shared services (PostgreSQL, Mailpit) ..."
if [[ ! -f /opt/generateu/shared/docker-compose.shared.yml ]]; then
    cp "${SCRIPT_DIR}/docker-compose.shared.yml" /opt/generateu/shared/docker-compose.shared.yml
fi
cd /opt/generateu/shared
docker compose -f docker-compose.shared.yml up -d
success "Shared services running."

# ---------------------------------------------------------------------------
# 9. Docker network
# ---------------------------------------------------------------------------
if docker network inspect generateu_network &>/dev/null; then
    success "Docker network 'generateu_network' already exists."
else
    info "Creating Docker network 'generateu_network' ..."
    docker network create generateu_network
    success "Docker network created."
fi

# Connect shared containers to the network (ignore errors if already connected)
docker network connect generateu_network generateu_postgres 2>/dev/null || true
docker network connect generateu_network generateu_mailpit 2>/dev/null || true

# ---------------------------------------------------------------------------
# 10. Firewall
# ---------------------------------------------------------------------------
info "Configuring firewall ..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
success "Firewall configured (SSH, HTTP, HTTPS)."

# ---------------------------------------------------------------------------
# 11. OVH credentials template
# ---------------------------------------------------------------------------
OVH_CREDS="/root/.ovh-credentials"
if [[ ! -f "$OVH_CREDS" ]]; then
    info "Creating OVH credentials template at ${OVH_CREDS} ..."
    cat > "$OVH_CREDS" <<'OVH'
# OVH API credentials for Certbot DNS challenge
# Generate at: https://eu.api.ovh.com/createToken/
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = YOUR_APP_KEY
dns_ovh_application_secret = YOUR_APP_SECRET
dns_ovh_consumer_key = YOUR_CONSUMER_KEY
OVH
    chmod 600 "$OVH_CREDS"
    success "OVH credentials template created."
else
    success "OVH credentials file already exists."
fi

# ---------------------------------------------------------------------------
# 12. Initialise project registry
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
echo "1. Edit OVH API credentials:"
echo "     nano /root/.ovh-credentials"
echo ""
echo "2. Request wildcard certificate:"
echo "     certbot certonly \\"
echo "       --dns-ovh \\"
echo "       --dns-ovh-credentials /root/.ovh-credentials \\"
echo "       --dns-ovh-propagation-seconds 60 \\"
echo "       -d 'karl-remy.fr' \\"
echo "       -d '*.karl-remy.fr'"
echo ""
echo "3. Add DNS records at OVH:"
echo "     A    *.karl-remy.fr  ->  91.134.132.141"
echo "     A    karl-remy.fr    ->  91.134.132.141"
echo ""
echo "4. Authenticate GitHub CLI:"
echo "     gh auth login"
echo ""
