# Sandboxed Claude Code via Docker Devcontainer

Run Claude Code in an isolated container that can only read/write the project folder, has no access to host user files, and restricts network access to essential services only.

## What's Isolated

| Resource | Access |
|---|---|
| Project folder (`/workspace`) | Read/write (bind-mounted from host) |
| Host home directory, SSH keys, AWS creds | Not mounted, invisible |
| Network | Allowlist-only: Claude API, GitHub, npm registry |
| Root access | None (runs as `node` user) |
| Claude config (`/home/node/.claude`) | Persistent Docker volume (survives rebuilds) |

## Quick Start

### Option A: Dev Container-Compatible Editor (VS Code, Cursor, etc.)

1. Install your editor's Dev Containers extension (e.g., [VS Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers), [Cursor](https://www.cursor.com/) has built-in support)
2. Open this project in your editor
3. Use the command palette to **"Reopen in Container"**
4. Open a terminal and run:
   ```bash
   claude --dangerously-skip-permissions
   ```

### Option B: CLI (no editor required)

```bash
cd /path/to/this/project

# Build the image
docker build -t claude-sandbox .devcontainer/

# Run the container
docker run -it \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -v claude-config:/home/node/.claude \
  -w /workspace \
  claude-sandbox

# Inside the container
claude --dangerously-skip-permissions
```

## Authentication

On first run, Claude Code will prompt you to authenticate. Your credentials are stored in the persistent `claude-config` volume, so you only need to do this once.

To pass an API key instead:

```bash
docker run -it \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -v claude-config:/home/node/.claude \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -w /workspace \
  claude-sandbox
```

## Why `--dangerously-skip-permissions` Is Safe Here

This flag auto-accepts all Claude Code permission prompts. Normally risky, but inside this container:

- **Filesystem**: Claude can only touch `/workspace` (your project). No host paths are mounted.
- **Network**: Firewall blocks everything except the Claude API, GitHub, and npm.
- **Privileges**: Runs as unprivileged `node` user. No sudo except for the firewall script.
- **Ephemeral**: Anything written outside `/workspace` disappears when the container stops.

## Network Allowlist

The firewall (`init-firewall.sh`) permits outbound traffic to:

| Service | Why |
|---|---|
| DNS (port 53) | Domain resolution |
| SSH (port 22) | Git over SSH |
| `api.anthropic.com` | Claude API |
| `registry.npmjs.org` | npm packages |
| GitHub IP ranges | Git operations, API |
| `sentry.io` | Error reporting |
| `statsig.anthropic.com` | Feature flags |
| Host network | Docker communication |

Everything else is blocked. You can verify with:

```bash
# Should fail
curl https://example.com

# Should succeed
curl https://api.anthropic.com
```

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Container image: Node 20, Claude Code CLI, dev tools, firewall utilities |
| `devcontainer.json` | Container config: mounts, capabilities, env vars, startup command |
| `init-firewall.sh` | Network lockdown: iptables allowlist, runs on container start |

## Rebuilding

```bash
# Force rebuild (e.g., after updating Claude Code version)
docker build --no-cache -t claude-sandbox .devcontainer/
```

Or in your editor: use the command palette → **"Rebuild Container"**
