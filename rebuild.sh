#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="agent-sandbox"

echo "Rebuilding $IMAGE_NAME (no cache)..."
docker build --no-cache -t "$IMAGE_NAME" .devcontainer/
