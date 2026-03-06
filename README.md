# Agent Sandbox

A hardened Docker container for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in isolation. Gives the agent a full development environment with web access while keeping it contained — no access to host files, credentials, or privileges.

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
- **Network**: HTTP/HTTPS and SSH are open; all other outbound traffic is blocked. Inbound traffic is blocked.
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

- **Bind-mount isolation** — Only `/workspace` is mounted from the host. Home directory, SSH keys, cloud credentials, and other sensitive paths are never exposed.
- **Non-root runtime** — The container runs as the unprivileged `node` user, not root.
- **No sudo** — `sudo` is not installed in the container, eliminating a privilege escalation vector.
- **Capability dropping** — `NET_ADMIN` and `NET_RAW` are added at startup only for firewall initialization, then permanently dropped via `setpriv` before the shell starts. The running process cannot modify network rules.
- **Minimal firewall** — Allows only DNS, SSH, HTTP, and HTTPS outbound. All other outbound traffic and all inbound traffic is blocked. Blocked connections return an immediate ICMP reject for fast failure.
- **Host network scoped to gateway** — Only the Docker gateway IP is reachable, not the entire host subnet. Sibling containers and host services are not exposed.

## Network Policy

The firewall (`init-firewall.sh`) allows only standard protocols:

| Allowed | Ports |
|---|---|
| DNS | UDP 53 |
| SSH | TCP 22 |
| HTTP | TCP 80 |
| HTTPS | TCP 443 |
| Docker host gateway | All |

Everything else is blocked. Port 3000 is forwarded so you can preview dev servers in your host browser.

The primary containment is **filesystem and privilege isolation**. The container cannot access host files, escalate privileges, or persist changes outside `/workspace`.

## Files

| File | Purpose |
|---|---|
| `run.sh` | Build & run script (single command entry point) |
| `rebuild.sh` | Force rebuild with no cache (e.g., after updating Claude Code version) |
| `.devcontainer/Dockerfile` | Container image: Node 20, Claude Code CLI, dev tools, firewall utilities |
| `.devcontainer/devcontainer.json` | VS Code / Cursor Dev Container config: mounts, capabilities, env vars |
| `.devcontainer/entrypoint.sh` | Container entrypoint: runs firewall init, installs GSD, drops capabilities |
| `.devcontainer/init-firewall.sh` | Minimal firewall: allows DNS/SSH/HTTP/HTTPS, blocks everything else |

## Rebuilding

```bash
./rebuild.sh
```

Or in your editor: use the command palette → **"Rebuild Container"**
