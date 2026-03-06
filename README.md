# Agent Sandbox

A hardened Docker container for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with network-level isolation. Gives the agent a full development environment while restricting outbound traffic to an allowlist of trusted services.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

## Quick Start

```bash
./run.sh
```

This builds the image and starts the container. You can also open the `.devcontainer/` folder in VS Code / Cursor with the Dev Containers extension.

Inside the container, run:

```bash
claude --dangerously-skip-permissions
```

To use an API key instead of interactive login:

```bash
ANTHROPIC_API_KEY=sk-ant-... ./run.sh
```

## Authentication

On first run, Claude Code will prompt you to authenticate. Your credentials are stored in a persistent Docker volume (`agent-sandbox-config` via `run.sh`, or a per-container volume in Dev Containers), so you only need to do this once.

## Why `--dangerously-skip-permissions` Is Safe Here

This flag auto-accepts all Claude Code permission prompts. Normally risky, but inside this container:

- **Filesystem**: Claude can only touch `/workspace` (your project). No host paths are mounted.
- **Network**: Firewall blocks everything except the Claude API, GitHub, and npm.
- **Privileges**: Runs as unprivileged `node` user. `sudo` is not installed.
- **Ephemeral**: Anything written outside `/workspace` disappears when the container stops.

## What's Inside

- **Node 20** base image with zsh, git, gh, fzf, git-delta, and common dev tools
- **Claude Code CLI** pre-installed globally
- **[Get Shit Done](https://www.npmjs.com/package/get-shit-done-cc)** (GSD) installed on first boot for task-driven workflows
- **Port 3000** forwarded for local dev servers

## Security

The container starts as root to configure an iptables firewall, then **drops `NET_ADMIN` and `NET_RAW` capabilities** before handing control to the unprivileged `node` user. The agent cannot modify or disable the firewall.

This sandbox provides defense in depth through multiple independent isolation layers:

- **Capability dropping** — `NET_ADMIN` and `NET_RAW` are added at startup only for firewall initialization, then permanently dropped via `setpriv` before the shell starts. The running process cannot modify network rules.
- **Default DROP policy** — All iptables chains (INPUT, FORWARD, OUTPUT) default to DROP. Only explicitly allowlisted traffic is permitted.
- **Non-root runtime** — The container runs as the unprivileged `node` user, not root.
- **Bind-mount isolation** — Only `/workspace` is mounted from the host. Home directory, SSH keys, cloud credentials, and other sensitive paths are never exposed.
- **Firewall validation** — `init-firewall.sh` tests both that blocked domains fail and allowed domains succeed, catching misconfiguration at startup.
- **REJECT over DROP for outbound** — Blocked outbound connections return an immediate ICMP error instead of timing out, so failures surface quickly rather than causing long hangs.
- **DNS restricted to internal resolver** — DNS queries are locked to Docker's internal resolver (`127.0.0.11`) only, preventing DNS tunneling and data exfiltration via arbitrary DNS servers.
- **No sudo** — `sudo` is not installed in the container, eliminating a privilege escalation vector.
- **Host network scoped to gateway** — Only the Docker gateway IP is reachable, not the entire host subnet. Sibling containers and host services are not exposed.

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
| `statsig.anthropic.com`, `statsig.com` | Feature flags |
| Host gateway | Docker communication |

Port 3000 is forwarded so you can preview dev servers in your host browser — for extra security, use an incognito window with no logged-in sessions.

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
| `run.sh` | Build & run script (single command entry point) |
| `.devcontainer/Dockerfile` | Container image: Node 20, Claude Code CLI, dev tools, firewall utilities |
| `.devcontainer/devcontainer.json` | VS Code / Cursor Dev Container config: mounts, capabilities, env vars |
| `.devcontainer/entrypoint.sh` | Container entrypoint: runs firewall init, installs GSD, drops capabilities |
| `.devcontainer/init-firewall.sh` | Network lockdown: iptables allowlist, runs on container start |

## Rebuilding

```bash
# Force rebuild (e.g., after updating Claude Code version)
docker build --no-cache -t agent-sandbox .devcontainer/
```

Or in your editor: use the command palette → **"Rebuild Container"**
