#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="agent-sandbox"

# Build the image
echo "Building $IMAGE_NAME..."
docker build -t "$IMAGE_NAME" .devcontainer/

# Run the container
echo "Starting container..."
exec docker run -it \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -p 3000:3000 \
  -v "$(pwd):/workspace" \
  -v agent-sandbox-config:/home/node/.claude \
  -w /workspace \
  -e CLAUDE_CONFIG_DIR=/home/node/.claude \
  ${ANTHROPIC_API_KEY:+-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
  "$IMAGE_NAME"
