#!/usr/bin/env bash
set -euo pipefail

# --- set these for your setup ---
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"    # or https://ntfy.yourdomain.tld
NTFY_TOPIC="${NTFY_TOPIC:-limbo_msging_done}"        # <- change me
NTFY_TOKEN="${NTFY_TOKEN:-}"               # optional, if your server requires it
NTFY_PRIORITY="${NTFY_PRIORITY:-4}"        # 1=lowest..5=highest
# ---------------------------------

# Read the hook JSON from stdin
payload="$(cat)"
message="$(printf '%s' "$payload" | jq -r '.message')"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name')"
perm_mode="$(printf '%s' "$payload" | jq -r '.permission_mode')"

# Send to ntfy
curl -fsSL \
  ${NTFY_TOKEN:+-u ":$NTFY_TOKEN"} \
  -H "X-Title: Claude Code ($event)" \
  -H "X-Priority: ${NTFY_PRIORITY}" \
  -H "Tags: robot,bell" \
  -d "$message • perm=$perm_mode" \
  "${NTFY_URL%/}/${NTFY_TOPIC}"
