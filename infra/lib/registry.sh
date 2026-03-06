#!/usr/bin/env bash
# =============================================================================
# registry.sh - Project registry management (/opt/generateu/registry.json)
#
# Uses jq to maintain a JSON file that tracks every deployed project,
# its assigned port, GitHub URL, and creation timestamp.
# =============================================================================

REGISTRY_FILE="/opt/generateu/registry.json"

# ---------------------------------------------------------------------------
# registry_init
#   Create the registry file with sensible defaults if it does not exist.
# ---------------------------------------------------------------------------
registry_init() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        mkdir -p "$(dirname "$REGISTRY_FILE")"
        cat > "$REGISTRY_FILE" <<'EOF'
{
  "projects": {},
  "next_port": 8001
}
EOF
        info "Registry initialised at ${REGISTRY_FILE}"
    fi
}

# ---------------------------------------------------------------------------
# registry_get_port <project>
#   Print the port assigned to <project>, or return 1 if not found.
# ---------------------------------------------------------------------------
registry_get_port() {
    local project="$1"
    local port
    port=$(jq -r --arg p "$project" '.projects[$p].port // empty' "$REGISTRY_FILE")
    if [[ -z "$port" ]]; then
        return 1
    fi
    echo "$port"
}

# ---------------------------------------------------------------------------
# registry_add <project> <port> <github_url>
#   Register a new project with its port and GitHub URL.
# ---------------------------------------------------------------------------
registry_add() {
    local project="$1"
    local port="$2"
    local github_url="$3"
    local created_at
    created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(mktemp)
    jq --arg p "$project" \
       --argjson port "$port" \
       --arg url "$github_url" \
       --arg ts "$created_at" \
       '.projects[$p] = {"port": $port, "github_url": $url, "created_at": $ts}' \
       "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ---------------------------------------------------------------------------
# registry_remove <project>
#   Delete a project entry from the registry.
# ---------------------------------------------------------------------------
registry_remove() {
    local project="$1"
    local tmp
    tmp=$(mktemp)
    jq --arg p "$project" 'del(.projects[$p])' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ---------------------------------------------------------------------------
# registry_next_port
#   Print the next available port and atomically increment the counter.
# ---------------------------------------------------------------------------
registry_next_port() {
    local port
    port=$(jq -r '.next_port' "$REGISTRY_FILE")
    echo "$port"

    local tmp
    tmp=$(mktemp)
    jq '.next_port += 1' "$REGISTRY_FILE" > "$tmp" && mv "$tmp" "$REGISTRY_FILE"
}

# ---------------------------------------------------------------------------
# registry_list
#   Pretty-print every registered project.
# ---------------------------------------------------------------------------
registry_list() {
    jq -r '.projects | to_entries[] | "\(.key)\t\(.value.port)\t\(.value.github_url)\t\(.value.created_at)"' "$REGISTRY_FILE"
}
