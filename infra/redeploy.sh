#!/usr/bin/env bash
# =============================================================================
# redeploy.sh - Redeploy an existing project after code changes
#
# Usage:  ./redeploy.sh <project-name>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/registry.sh"

DOMAIN="karl-remy.fr"
PROJECTS_DIR="/opt/generateu/projects"

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"
CONTAINER_NAME="${PROJECT_NAME}_app"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
registry_init

if ! registry_get_port "$PROJECT_NAME" &>/dev/null; then
    error "Project '${PROJECT_NAME}' not found in registry."
    exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Project directory ${PROJECT_DIR} does not exist."
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Pull latest code
# ---------------------------------------------------------------------------
info "Pulling latest code ..."
cd "$PROJECT_DIR"
git pull --ff-only
success "Code updated."

# ---------------------------------------------------------------------------
# 2. Rebuild Docker image (no cache)
# ---------------------------------------------------------------------------
info "Rebuilding Docker image (no cache) ..."
docker compose -f docker-compose.prod.yml build --no-cache
success "Docker image rebuilt."

# ---------------------------------------------------------------------------
# 3. Restart containers
# ---------------------------------------------------------------------------
info "Restarting containers ..."
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
success "Containers restarted."

# Wait for the app to be ready
sleep 5

# ---------------------------------------------------------------------------
# 4. Run migrations
# ---------------------------------------------------------------------------
info "Running database migrations ..."
docker exec "${CONTAINER_NAME}" php bin/console doctrine:migrations:migrate --no-interaction
success "Migrations applied."

# ---------------------------------------------------------------------------
# 5. Clear cache
# ---------------------------------------------------------------------------
info "Clearing cache ..."
docker exec "${CONTAINER_NAME}" php bin/console cache:clear
success "Cache cleared."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${RESET}"
echo -e "${GREEN}  Project redeployed successfully!${RESET}"
echo -e "${GREEN}============================================${RESET}"
echo ""
echo -e "  ${BOLD}Name:${RESET}  ${PROJECT_NAME}"
echo -e "  ${BOLD}URL:${RESET}   https://${PROJECT_NAME}.${DOMAIN}"
echo ""
