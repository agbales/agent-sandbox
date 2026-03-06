# Vibecode Sandbox

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

```bash
./run.sh
```

This builds the image and starts the container. Inside, run:

```bash
claude --dangerously-skip-permissions
```

To pass an API key:

```bash
ANTHROPIC_API_KEY=sk-ant-... ./run.sh
```

## Authentication

On first run, Claude Code will prompt you to authenticate. Your credentials are stored in the persistent `claude-config` volume, so you only need to do this once.

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
| `Dockerfile` | Container image: Node 20, Claude Code CLI, dev tools, firewall utilities |
| `devcontainer.json` | Container config: mounts, capabilities, env vars, startup command |
| `init-firewall.sh` | Network lockdown: iptables allowlist, runs on container start |

## Security Model

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

## Rebuilding

```bash
# Force rebuild (e.g., after updating Claude Code version)
docker build --no-cache -t vibecode-sandbox .devcontainer/
```

Or in your editor: use the command palette → **"Rebuild Container"**
