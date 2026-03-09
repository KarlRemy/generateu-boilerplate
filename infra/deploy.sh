#!/usr/bin/env bash
# =============================================================================
# deploy.sh - Deploy a new Symfony project as a subdomain of karl-remy.fr
#
# Usage:  ./deploy.sh <project-name>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/secrets.sh"
source "${SCRIPT_DIR}/lib/registry.sh"

DOMAIN="karl-remy.fr"
GITHUB_ORG="KarlRemy"
TEMPLATE_REPO="${GITHUB_ORG}/generateu-boilerplate"
PROJECTS_DIR="/opt/generateu/projects"
CADDY_CONF_DIR="/opt/generateu/shared/caddy"
CADDY_TEMPLATE="${SCRIPT_DIR}/caddy/subdomain.caddy.template"

# ---------------------------------------------------------------------------
# GH_TOKEN - load from config file if not already set
# ---------------------------------------------------------------------------
GENERATEU_CONF="/opt/generateu/.env"
if [[ -z "${GH_TOKEN:-}" && -f "$GENERATEU_CONF" ]]; then
    source "$GENERATEU_CONF"
fi
if [[ -z "${GH_TOKEN:-}" ]]; then
    error "GH_TOKEN is not set."
    error "Store it once:  echo 'GH_TOKEN=ghp_...' | sudo tee /opt/generateu/.env"
    exit 1
fi
export GH_TOKEN

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"

# Validate name: lowercase letters, digits, hyphens only
if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    error "Invalid project name '${PROJECT_NAME}'. Use lowercase alphanumeric and hyphens only."
    exit 1
fi

PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"
DB_NAME="db_${PROJECT_NAME//-/_}"
DB_USER="user_${PROJECT_NAME//-/_}"
CONTAINER_NAME="${PROJECT_NAME}_app"
GITHUB_URL="https://github.com/${GITHUB_ORG}/${PROJECT_NAME}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
registry_init

if registry_get_port "$PROJECT_NAME" &>/dev/null; then
    error "Project '${PROJECT_NAME}' already exists in the registry."
    exit 1
fi

if [[ -d "$PROJECT_DIR" ]]; then
    error "Directory ${PROJECT_DIR} already exists."
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Assign port
# ---------------------------------------------------------------------------
PORT=$(registry_next_port)
info "Assigned port ${PORT} to project '${PROJECT_NAME}'."

# ---------------------------------------------------------------------------
# 2. Create GitHub repo from template and clone
# ---------------------------------------------------------------------------
info "Creating GitHub repository from template ..."
gh repo create "${GITHUB_ORG}/${PROJECT_NAME}" \
    --template "$TEMPLATE_REPO" \
    --public
success "Repository created."

info "Cloning repository ..."
sleep 3
gh repo clone "${GITHUB_ORG}/${PROJECT_NAME}" "$PROJECT_DIR"
success "Repository cloned to ${PROJECT_DIR}."

# ---------------------------------------------------------------------------
# 3. Create PostgreSQL database and user
# ---------------------------------------------------------------------------
DB_PASSWORD=$(generate_password)

info "Creating PostgreSQL database '${DB_NAME}' and user '${DB_USER}' ..."
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
success "Database ready."

# ---------------------------------------------------------------------------
# 4. Generate secrets
# ---------------------------------------------------------------------------
APP_SECRET=$(generate_secret 32)
MERCURE_JWT_SECRET=$(generate_secret 32)

# ---------------------------------------------------------------------------
# 5. Write .env for docker-compose variables
# ---------------------------------------------------------------------------
info "Writing environment files ..."
# Append docker-compose variables to the existing .env (don't overwrite Symfony defaults)
sed -i "s/^PROJECT_NAME=.*/PROJECT_NAME=${PROJECT_NAME}/" "${PROJECT_DIR}/.env"
if ! grep -q '^APP_PORT=' "${PROJECT_DIR}/.env"; then
    echo "APP_PORT=${PORT}" >> "${PROJECT_DIR}/.env"
else
    sed -i "s/^APP_PORT=.*/APP_PORT=${PORT}/" "${PROJECT_DIR}/.env"
fi

cat > "${PROJECT_DIR}/.env.prod.local" <<ENV
APP_ENV=prod
APP_SECRET=${APP_SECRET}
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@host.docker.internal:5432/${DB_NAME}?serverVersion=17&charset=utf8
DEFAULT_URI=https://${PROJECT_NAME}.${DOMAIN}
MERCURE_JWT_SECRET=${MERCURE_JWT_SECRET}
MERCURE_URL=https://${PROJECT_NAME}.${DOMAIN}/.well-known/mercure
MERCURE_PUBLIC_URL=https://${PROJECT_NAME}.${DOMAIN}/.well-known/mercure
MAILER_DSN=smtp://generateu_mailpit:1025
CORS_ORIGIN=https://${PROJECT_NAME}.${DOMAIN}
ENV
success "Environment files written."

# ---------------------------------------------------------------------------
# 6. Build and start Docker containers
# ---------------------------------------------------------------------------
info "Building Docker image ..."
cd "$PROJECT_DIR"
docker compose -f docker-compose.prod.yml build
success "Docker image built."

info "Starting containers ..."
docker compose -f docker-compose.prod.yml up -d
success "Containers started."

info "Waiting for app to be ready ..."
sleep 8

# ---------------------------------------------------------------------------
# 7. Run migrations
# ---------------------------------------------------------------------------
info "Running database migrations ..."
docker exec "${CONTAINER_NAME}" php bin/console doctrine:migrations:migrate --no-interaction
success "Migrations applied."

# ---------------------------------------------------------------------------
# 8. Fixtures (skipped in prod - DoctrineFixturesBundle is dev-only)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 9. Create Caddy reverse proxy config
# ---------------------------------------------------------------------------
info "Creating Caddy config for ${PROJECT_NAME}.${DOMAIN} ..."
mkdir -p "$CADDY_CONF_DIR"
sed -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s/PROJECT_PORT/${PORT}/g" \
    "$CADDY_TEMPLATE" > "${CADDY_CONF_DIR}/${PROJECT_NAME}.caddy"
success "Caddy config written."

# ---------------------------------------------------------------------------
# 10. Reload FrankenPHP (gere les sous-domaines via import dans le Caddyfile)
# ---------------------------------------------------------------------------
info "Reloading FrankenPHP ..."
systemctl reload frankenphp 2>/dev/null || systemctl restart frankenphp 2>/dev/null || systemctl restart caddy 2>/dev/null
success "Reverse proxy reloaded."

# ---------------------------------------------------------------------------
# 11. Update registry
# ---------------------------------------------------------------------------
registry_add "$PROJECT_NAME" "$PORT" "$GITHUB_URL"
success "Registry updated."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${RESET}"
echo -e "${GREEN}  Project deployed successfully!${RESET}"
echo -e "${GREEN}============================================${RESET}"
echo ""
echo -e "  ${BOLD}Name:${RESET}   ${PROJECT_NAME}"
echo -e "  ${BOLD}URL:${RESET}    https://${PROJECT_NAME}.${DOMAIN}"
echo -e "  ${BOLD}Port:${RESET}   ${PORT}"
echo -e "  ${BOLD}GitHub:${RESET} ${GITHUB_URL}"
echo -e "  ${BOLD}DB:${RESET}     ${DB_NAME}"
echo -e "  ${BOLD}Admin:${RESET}  admin@example.com / password"
echo ""
