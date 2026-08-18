# Shared knowledge base

`ai/install-kb.sh` wires this machine's agents into a shared [iwe](https://github.com/iwe-org/iwe)
knowledge base exposed over MCP, so every agent reads and writes the same notes.

```bash
ai/install-kb.sh
```

Idempotent, and run automatically by `install.sh` (skip with `SKIP_KB=1`).

| Agent | What gets written |
|---|---|
| Hermes | `~/.hermes/config.yaml` -> `mcp_servers.iwe`, plus the skill |
| omp | `~/.mcp.json` -> `mcpServers.iwe`, plus the skill |

`.mcp.json` is the Claude Code convention, so Claude Code / Codex / OpenCode
pick up the same server.

## Requirements

- tailscale installed and connected (the KB lives on a tailnet host)
- the KB reachable; the script aborts rather than writing a broken config

Point it elsewhere with `KB_URL=https://your-host/mcp ai/install-kb.sh`.
The hostname is derived from the URL, so that is the only knob.

## Why

Agents keep re-deriving the same facts. The KB stores them once, with
provenance (`measured` / `primary` / `inferred`), so a later agent can tell a
measurement from a guess. `ai/skills/shared-knowledge-base/SKILL.md` is the
behavioural contract: search before answering, write durable facts at the end
of a task, never overwrite - supersede.

