#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="claude-sandbox"

# Build the image
echo "Building $IMAGE_NAME..."
docker build -t "$IMAGE_NAME" .devcontainer/

# Run the container
echo "Starting container..."
exec docker run -it \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -v claude-config:/home/node/.claude \
  -w /workspace \
  ${ANTHROPIC_API_KEY:+-e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"} \
  "$IMAGE_NAME"
