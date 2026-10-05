---
name: shared-knowledge-base
description: Use when you learn or need a durable technical fact.
---

# Shared knowledge base (iwe)

One KB shared by every agent on the tailnet: Hermes (mac, moltbot), omp (a3),
Grok, and any MCP client. Endpoint `https://iwe.story-nessie.ts.net/mcp`.
Files live on node at `/mnt/user/appdata/iwe/kb`, git-backed, autopushed hourly.

## Read first

Before researching or answering a durable technical question, search the KB:

- `iwe_find` - fuzzy/lexical discovery, returns keys + frontmatter
- `iwe_retrieve` - full content for given keys, expands the graph

If the KB answers it, use that and cite the doc key. Do not re-derive.

## Write reflex

At the end of a task, write an entry when you have a DURABLE fact:

- measured a number (VRAM, throughput, latency, size)
- root-caused a failure and know the chain
- found a config/flag/command that works, or a trap that does not
- learned a stable fact about Khoi's hardware or services

Do NOT write: session progress, secrets/tokens, PR or commit numbers,
anything stale within a week, or a restatement of something already there.

## Provenance is mandatory

Every entry starts with frontmatter at byte 0:

```yaml
---
source: measured
confidence: high
agent: <you>@<host>
verified_at: YYYY-MM-DD
---
```

`source` values, in descending trust:

- `measured` - you ran a command and observed the output
- `primary`  - read from an authoritative file or vendor doc
- `user-asserted` - Khoi stated it about his own hardware
- `inferred` - derived, estimated, scaled, or reasoned

**Default to `inferred` unless you actually ran the command.**

Mislabeling an estimate as `measured` is the worst failure mode here: every
other agent then treats a guess as fact. This has already happened once -
`gpu-quant-context-fit` was tagged `measured` when only one row was measured
and the rest were scaled estimates. A subagent caught it. Do not repeat it.

Mixed doc? Tag the doc `inferred` and mark per-row basis in a table column.

## Avoid duplicates

1. `iwe_find` for the topic BEFORE writing.
2. If a doc exists, `iwe_update` it instead of creating a near-twin.
3. Use `if_exists: "skip"` on `iwe_create` so retries are idempotent.
4. Fix `orphan: no page links here` warnings by linking the new doc from
   `infra`, `hardware`, or another index page. Orphans never get found.

## Style

- Key: short kebab-case, e.g. `node-3090-kv-cache`.
- One `# Title` heading matching the topic.
- Show the evidence: the command, the numbers, the observed output.
- Link related docs with `[text](other-key)`.
- Correct wrong entries in place; note what changed and why.

