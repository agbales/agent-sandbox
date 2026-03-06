#!/bin/bash
set -euo pipefail

# Install GSD (Get Shit Done) for Claude Code if not already installed
if [ ! -d "$HOME/.claude/commands/gsd" ]; then
  echo "Installing Get Shit Done for Claude Code..."
  npx --yes get-shit-done-cc@latest --claude --global
fi

exec "$@"
