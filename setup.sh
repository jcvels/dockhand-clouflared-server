#!/usr/bin/env bash
set -euo pipefail

prompt() {
  local var="$1"
  local label="$2"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$label: " value
    if [[ -z "$value" ]]; then
      echo "Error: $label cannot be empty." >&2
    fi
  done
  eval "$var='$value'"
}

prompt TOKEN "TUNNEL_TOKEN (Cloudflare tunnel token)"
prompt DOMAIN "DOCKHAND_DOMAIN (e.g. app.example.com)"

cat > .env <<EOF
TUNNEL_TOKEN=$TOKEN
DOCKHAND_DOMAIN=$DOMAIN
EOF

mkdir -p dockhand

echo
echo ".env file and ./dockhand folder created."
echo "Next, run:"
echo "  docker compose up -d"
