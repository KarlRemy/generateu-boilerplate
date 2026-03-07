#!/usr/bin/env bash
# =============================================================================
# status.sh - Show status of all deployed Generateu projects
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/registry.sh"

DOMAIN="karl-remy.fr"
PROJECTS_DIR="/opt/generateu/projects"

registry_init

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Generateu - Deployed Projects${RESET}"
echo "=============================================================="
printf "%-20s %-6s %-30s %-12s %s\n" "NAME" "PORT" "URL" "STATUS" "UPTIME"
echo "--------------------------------------------------------------"

# ---------------------------------------------------------------------------
# Iterate over registered projects
# ---------------------------------------------------------------------------
FOUND=0

while IFS=$'\t' read -r name port github_url created_at; do
    FOUND=1
    url="https://${name}.${DOMAIN}"
    container="${name}-app"

    # Query Docker for container status
    if docker inspect --format='{{.State.Status}}' "$container" &>/dev/null; then
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        started_at=$(docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null)

        # Calculate uptime
        if [[ "$status" == "running" ]]; then
            start_epoch=$(date -d "$started_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%%.*}" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            if [[ "$start_epoch" -gt 0 ]]; then
                diff=$(( now_epoch - start_epoch ))
                days=$(( diff / 86400 ))
                hours=$(( (diff % 86400) / 3600 ))
                mins=$(( (diff % 3600) / 60 ))
                uptime="${days}d ${hours}h ${mins}m"
            else
                uptime="unknown"
            fi
            status_display="${GREEN}running${RESET}"
        else
            uptime="-"
            status_display="${RED}${status}${RESET}"
        fi
    else
        status_display="${RED}not found${RESET}"
        uptime="-"
    fi

    printf "%-20s %-6s %-30s " "$name" "$port" "$url"
    echo -e "${status_display}\t${uptime}"
done < <(registry_list)

if [[ "$FOUND" -eq 0 ]]; then
    echo -e "  ${YELLOW}No projects deployed yet.${RESET}"
fi

echo "=============================================================="

# ---------------------------------------------------------------------------
# Shared services
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Shared Services${RESET}"
echo "--------------------------------------------------------------"

# PostgreSQL (natif)
if systemctl is-active --quiet postgresql; then
    echo -e "  postgresql:  ${GREEN}running${RESET}"
else
    echo -e "  postgresql:  ${RED}stopped${RESET}"
fi

# Mailpit (Docker)
if docker inspect --format='{{.State.Status}}' generateu_mailpit &>/dev/null; then
    svc_status=$(docker inspect --format='{{.State.Status}}' generateu_mailpit 2>/dev/null)
    if [[ "$svc_status" == "running" ]]; then
        echo -e "  generateu_mailpit:  ${GREEN}running${RESET}"
    else
        echo -e "  generateu_mailpit:  ${RED}${svc_status}${RESET}"
    fi
else
    echo -e "  generateu_mailpit:  ${RED}not found${RESET}"
fi

# Caddy
if systemctl is-active --quiet caddy; then
    echo -e "  caddy:  ${GREEN}running${RESET}"
else
    echo -e "  caddy:  ${RED}stopped${RESET}"
fi

echo ""
