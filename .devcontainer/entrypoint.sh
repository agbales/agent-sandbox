#!/bin/bash
set -euo pipefail

# === Root phase: set up firewall ===
/usr/local/bin/init-firewall.sh

# === Install GSD as node user ===
if [ ! -d "/home/node/.claude/commands/gsd" ]; then
  echo "Installing Get Shit Done for Claude Code..."
  su -s /bin/bash node -c 'npx --yes get-shit-done-cc@latest --claude --global'
fi

# === Drop NET_ADMIN/NET_RAW capabilities, switch to node, exec command ===
exec setpriv \
  --reuid=node --regid=node --init-groups \
  --bounding-set=-net_admin,-net_raw \
  -- "$@"
