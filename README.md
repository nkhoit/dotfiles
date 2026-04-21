# dotfiles

Cross-platform dev environment setup — Windows, macOS, Ubuntu.

**Stack:** Neovim (LazyVim) · Neovide (GUI) · Zellij · Starship · PowerShell (Win) / Zsh (Unix) · fzf

## Quick Start

### macOS / Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/nkhoit/dotfiles/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/nkhoit/dotfiles/main/install.ps1 | iex
```

> **Note:** Run PowerShell as Administrator, or enable **Developer Mode** (Settings → For Developers) for symlink support.

## What Gets Installed

| Tool | macOS | Ubuntu | Windows |
|------|-------|--------|---------|
| **Neovim** | brew | GitHub release | winget |
| **Neovide** | brew cask | GitHub release (x86_64) | winget |
| **Starship** | brew | installer script | winget |
| **Zellij** | brew | GitHub release | — |
| **fzf** | brew | git clone | winget |
| **ripgrep** | brew | apt | winget |
| **fd** | brew | apt | winget |
| **Node.js** | brew | NodeSource | winget |
| **Python** | brew | apt | winget |
| **JetBrains Mono Nerd Font** | brew cask | GitHub release | winget |

## What Gets Linked

| Config | Destination |
|--------|-------------|
| `nvim/` | `~/.config/nvim` (Unix) · `%LOCALAPPDATA%\nvim` (Win) |
| `neovide/config.toml` | `~/.config/neovide/config.toml` (Unix, respects `$XDG_CONFIG_HOME`) · `%APPDATA%\neovide\config.toml` (Win) |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `zellij/config.kdl` | `~/.config/zellij/config.kdl` |
| `zsh/.zshrc` | `~/.zshrc` |
| `powershell/...profile.ps1` | `$PROFILE` |
| `copilot/instructions.md` | `~/.copilot/instructions.md` |

Existing configs are backed up with a `.backup.<timestamp>` suffix before linking.

## Structure

```
├── install.sh              # macOS/Linux installer
├── install.ps1             # Windows installer
├── nvim/                   # Neovim (LazyVim) config
├── neovide/                # Neovide GUI launch defaults
├── starship/               # Starship prompt config
├── zellij/                 # Zellij terminal multiplexer config
├── copilot/                # GitHub Copilot CLI global instructions
├── powershell/             # PowerShell profile (Windows)
└── zsh/                    # Zsh config (macOS/Linux)
```

## Manual Steps After Install

1. **Set your terminal font** to `JetBrainsMono Nerd Font` for icons to render
2. **Neovim plugins** install automatically on first launch — just run `nvim`
3. **Zsh plugins** (autosuggestions, syntax-highlighting) install on first shell open

## Re-Running

Both scripts are idempotent — safe to run again to pick up changes:

```bash
~/.dotfiles/install.sh       # Unix
~/.dotfiles/install.ps1      # Windows
```

Or just `git pull` inside `~/.dotfiles` — symlinks mean configs update instantly.
