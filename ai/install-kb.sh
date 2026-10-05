#!/usr/bin/env bash
set -euo pipefail
KB_URL="${KB_URL:-https://iwe.story-nessie.ts.net/mcp}"
KB_HOST="$(printf %s "$KB_URL" | sed -E 's#^https?://([^/]+).*#\1#')"
HERMES_DIR="${HERMES_DIR:-$HOME/.hermes}"
DOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ok(){ printf '  \033[32mok\033[0m %s\n' "$1"; }
warn(){ printf '  \033[33m!!\033[0m %s\n' "$1"; }
die(){ printf '  \033[31mxx\033[0m %s\n' "$1"; exit 1; }
echo 'wiring agents -> shared knowledge base'

# 1. tailscale present? (macOS app installs outside the default PATH)
TS=""
for c in tailscale /opt/homebrew/bin/tailscale /usr/local/bin/tailscale \
         "/Applications/Tailscale.app/Contents/MacOS/Tailscale"; do
  command -v "$c" >/dev/null 2>&1 && { TS="$c"; break; }
  [ -x "$c" ] && { TS="$c"; break; }
done
if [ -n "$TS" ]; then
  if "$TS" status >/dev/null 2>&1; then ok 'tailscale up'
  else die 'tailscale installed but not connected - run: tailscale up'; fi
else
  warn 'tailscale CLI not found'
  warn 'install: https://tailscale.com/download   then: tailscale up'
  die 'cannot reach the KB without tailscale'
fi

# 2. KB reachable? 406 = alive (MCP wants an SSE Accept header)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$KB_URL" 2>/dev/null) || code=000
case "$code" in
  406|200|405) ok "kb reachable ($code)" ;;
  000|"") die "cannot reach $KB_HOST - is it up and in your tailnet ACLs?" ;;
  *) warn "kb returned $code - continuing anyway" ;;
esac

# 3+4. Hermes, if present on this machine
CFG=""
if [ -d "$HERMES_DIR" ] && [ -f "$HERMES_DIR/config.yaml" ]; then
  CFG="$HERMES_DIR/config.yaml"
  if grep -q 'iwe.story-nessie' "$CFG"; then
    ok 'hermes: mcp_servers already wired'
  else
    cp "$CFG" "$CFG.bak-kb-$(date +%Y%m%d%H%M%S)"
    if grep -q '^mcp_servers:' "$CFG"; then
      warn 'hermes: mcp_servers exists - add the iwe block manually:'
      printf '    iwe:\n      url: "%s"\n' "$KB_URL"
    else
      printf '\nmcp_servers:\n  iwe:\n    url: "%s"\n' "$KB_URL" >> "$CFG"
      ok 'hermes: added mcp_servers.iwe'
    fi
  fi
else
  warn 'hermes not found - skipping'
fi

# 5. install the write-reflex skill
SRC="$DOT_DIR/skills/shared-knowledge-base"
[ -d "$SRC" ] || die "skill source missing at $SRC"
if [ -n "$CFG" ]; then
  mkdir -p "$HERMES_DIR/skills"
  rm -rf "$HERMES_DIR/skills/shared-knowledge-base"
  cp -r "$SRC" "$HERMES_DIR/skills/shared-knowledge-base"
  ok 'hermes: skill installed'
fi

# 5b. omp (non-hermes coding agent) - .mcp.json + skill
OMP_SKILLS=""
[ -d "$HOME/.omp/agent" ] && OMP_SKILLS="$HOME/.omp/agent/skills"
if [ -n "$OMP_SKILLS" ]; then
  MCPJSON="$HOME/.mcp.json"
  if [ -f "$MCPJSON" ] && grep -q 'iwe.story-nessie' "$MCPJSON"; then
    ok 'omp .mcp.json already wired'
  else
    [ -f "$MCPJSON" ] && cp "$MCPJSON" "$MCPJSON.bak-$(date +%Y%m%d)"
    printf '{\n  "mcpServers": {\n    "iwe": {\n      "url": "%s"\n    }\n  }\n}\n' "$KB_URL" > "$MCPJSON"
    ok 'omp .mcp.json written'
  fi
  mkdir -p "$OMP_SKILLS/shared-knowledge-base"
  cp "$SRC/SKILL.md" "$OMP_SKILLS/shared-knowledge-base/SKILL.md"
  ok 'omp skill installed'
fi

# 5c. grok — skill link + remote MCP server
GROK_BIN=""
if command -v grok >/dev/null 2>&1; then
  GROK_BIN="grok"
elif [ -x "$HOME/.grok/bin/grok" ]; then
  GROK_BIN="$HOME/.grok/bin/grok"
elif [ -x "$HOME/.grok/bin/grok.exe" ]; then
  GROK_BIN="$HOME/.grok/bin/grok.exe"
fi
if [ -n "$GROK_BIN" ]; then
  mkdir -p "$HOME/.grok/skills"
  skill_dest="$HOME/.grok/skills/shared-knowledge-base"
  # A real directory makes ln nest a second copy on the next run.
  if [ -e "$skill_dest" ] && [ ! -L "$skill_dest" ]; then
    rm -rf "$skill_dest"
  fi
  ln -sfn "$SRC" "$skill_dest"
  ok 'grok: skill linked'
  if "$GROK_BIN" mcp add --transport http iwe "$KB_URL"; then
    ok 'grok: mcp iwe wired'
  else
    warn 'grok: could not add mcp server iwe'
  fi
else
  warn 'grok not found - skipping'
fi

# 6. validate yaml if python is around
if [ -n "$CFG" ] && command -v python3 >/dev/null 2>&1; then
  python3 -c "import yaml,sys; yaml.safe_load(open('$CFG'))" 2>/dev/null \
    && ok 'config.yaml parses' || die 'config.yaml is now INVALID - restore the .bak'
fi

echo
echo 'done.'
if [ -n "$CFG" ]; then
  echo 'restart hermes to register the mcp tools:'
  echo '  macos:  launchctl kickstart -k gui/$(id -u)/ai.hermes.gateway'
  echo '  linux:  systemctl --user restart hermes-gateway'
fi
[ -n "$OMP_SKILLS" ] && echo 'omp picks up .mcp.json on its next run.'
exit 0
