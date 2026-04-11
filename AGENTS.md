# AGENTS.md — dotfiles

Cross-platform dotfiles repo targeting **Windows, macOS, and Ubuntu**. Every change must work on all three.

## Platform Rules

1. **Prefer platform-agnostic solutions.** If a tool/config works identically on all three OSes, use it. Don't split by platform unless forced to.
2. **When platform-specific code is unavoidable**, implement all three (Windows, macOS, Ubuntu) — not just the one being tested. Document *why* the split is necessary.
3. **Shell scripts come in pairs:** `install.sh` (macOS + Ubuntu) and `install.ps1` (Windows). Keep them in sync — a feature in one must exist in the other.
4. **Configs that are identical across platforms** live once, symlinked everywhere (nvim, starship, copilot). Don't duplicate.
5. **Configs that differ by platform** get their own directory (powershell/, zsh/). The install scripts handle routing.

## Package Installation

| Platform | Manager | Notes |
|----------|---------|-------|
| macOS | Homebrew | Preferred for everything |
| Ubuntu | apt + curl/GitHub releases | apt for what's current; GitHub releases for nvim, starship, zellij |
| Windows | winget | Preferred for everything; PSGallery for PowerShell modules |

When adding a new tool, add it to **both** install scripts. If it's not available on a platform, document why and skip gracefully — don't error out.

## Symlinks

- **macOS/Ubuntu:** Standard symlinks via `ln -sf`.
- **Windows:** Symlinks if Developer Mode is enabled; fall back to copy with a warning. Use junctions for directories where possible.

## Testing Changes

Before committing, verify:
- `bash -n install.sh` (syntax check)
- PowerShell: `pwsh -NoProfile -Command "& { . '.\install.ps1' }" ` or at minimum review the logic
- Configs load without errors on the target shell

## File Layout

```
├── install.sh          # macOS/Linux bootstrap
├── install.ps1         # Windows bootstrap
├── nvim/               # Neovim — identical on all platforms
├── starship/           # Starship prompt — identical on all platforms
├── copilot/            # GitHub Copilot CLI — identical on all platforms
├── zellij/             # Zellij — macOS/Linux only
├── powershell/         # PowerShell profile — Windows only
└── zsh/                # Zsh config — macOS/Linux only
```

## Anti-Patterns

- Don't add a tool without adding it to install scripts on all supported platforms.
- Don't hardcode paths — use `$HOME`, `$env:USERPROFILE`, `$env:LOCALAPPDATA`, etc.
- Don't assume a package manager version — check if a tool exists before installing.
- Don't break idempotency — scripts must be safe to re-run.
