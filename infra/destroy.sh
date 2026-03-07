#!/usr/bin/env bash
# =============================================================================
# destroy.sh - Completely remove a deployed project
#
# Usage:  ./destroy.sh <project-name> --confirm
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/registry.sh"

PROJECTS_DIR="/opt/generateu/projects"
CADDY_CONF_DIR="/opt/generateu/shared/caddy"

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]] || [[ "$2" != "--confirm" ]]; then
    error "Usage: $0 <project-name> --confirm"
    error ""
    error "This will PERMANENTLY destroy the project, its database, and all data."
    error "Pass --confirm to proceed."
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"
DB_NAME="db_${PROJECT_NAME//-/_}"
DB_USER="user_${PROJECT_NAME//-/_}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
registry_init

if ! registry_get_port "$PROJECT_NAME" &>/dev/null; then
    warn "Project '${PROJECT_NAME}' not found in registry. Attempting cleanup anyway ..."
fi

# ---------------------------------------------------------------------------
# 1. Stop and remove containers
# ---------------------------------------------------------------------------
if [[ -d "$PROJECT_DIR" ]]; then
    info "Stopping containers ..."
    cd "$PROJECT_DIR"
    docker compose -f docker-compose.prod.yml down --volumes --remove-orphans 2>/dev/null || true
    success "Containers stopped."
else
    warn "Project directory not found, skipping container shutdown."
fi

# ---------------------------------------------------------------------------
# 2. Remove project directory
# ---------------------------------------------------------------------------
if [[ -d "$PROJECT_DIR" ]]; then
    info "Removing project directory ${PROJECT_DIR} ..."
    rm -rf "$PROJECT_DIR"
    success "Directory removed."
fi

# ---------------------------------------------------------------------------
# 3. Drop database and user
# ---------------------------------------------------------------------------
info "Dropping database '${DB_NAME}' and user '${DB_USER}' ..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || warn "Could not drop database."
sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" 2>/dev/null || warn "Could not drop user."
success "Database resources cleaned up."

# ---------------------------------------------------------------------------
# 4. Remove Caddy config
# ---------------------------------------------------------------------------
CADDY_FILE="${CADDY_CONF_DIR}/${PROJECT_NAME}.caddy"
if [[ -f "$CADDY_FILE" ]]; then
    info "Removing Caddy config ..."
    rm -f "$CADDY_FILE"
    success "Caddy config removed."
fi

# ---------------------------------------------------------------------------
# 5. Reload Caddy
# ---------------------------------------------------------------------------
info "Reloading reverse proxy ..."
systemctl reload frankenphp 2>/dev/null || systemctl restart frankenphp 2>/dev/null || systemctl restart caddy 2>/dev/null
success "Reverse proxy reloaded."

# ---------------------------------------------------------------------------
# 6. Update registry
# ---------------------------------------------------------------------------
registry_remove "$PROJECT_NAME"
success "Registry updated."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${RED}============================================${RESET}"
echo -e "${RED}  Project '${PROJECT_NAME}' destroyed.${RESET}"
echo -e "${RED}============================================${RESET}"
echo ""
