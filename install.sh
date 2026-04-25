#!/usr/bin/env bash
set -euo pipefail

# ===========================================================================
# dotfiles installer — macOS & Ubuntu/Debian
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nkhoit/dotfiles/main/install.sh | bash
#   — OR —
#   git clone git@github.com:nkhoit/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh
# ===========================================================================

DOTFILES_DIR="${HOME}/.dotfiles"
DOTFILES_REPO="https://github.com/nkhoit/dotfiles.git"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$*"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$*"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$*"; }
err()   { printf "\033[1;31m[error]\033[0m %s\n" "$*"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

OS="unknown"
detect_os() {
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian|pop|linuxmint) OS="debian" ;;
          fedora|rhel|centos|rocky|alma) OS="fedora" ;;
          *) OS="linux" ;;
        esac
      else
        OS="linux"
      fi
      ;;
    *) err "Unsupported OS: $(uname -s)" ;;
  esac
  info "Detected OS: ${OS}"
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
install_homebrew() {
  if ! command_exists brew; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    if [[ "$OS" == "macos" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
    else
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)" || true
    fi
  fi
  ok "Homebrew ready"
}

install_packages_macos() {
  install_homebrew
  info "Installing packages via Homebrew..."
  brew install neovim starship fzf ripgrep fd git curl zsh node python3
  # Zellij
  if ! command_exists zellij; then
    brew install zellij
  fi
  # Nerd Font for starship/LazyVim icons
  brew install --cask font-caskaydia-cove-nerd-font 2>/dev/null || true

  # Neovide (GUI for Neovim)
  if ! brew list --cask neovide &>/dev/null; then
    info "Installing Neovide..."
    brew install --cask neovide
  fi

  ok "macOS packages installed"
}

install_packages_debian() {
  info "Updating apt..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    git curl wget unzip tar gzip \
    build-essential \
    zsh ripgrep fd-find \
    python3 python3-pip python3-venv \
    xclip

  # Node.js (LTS via NodeSource if not present)
  if ! command_exists node; then
    info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
  fi

  # Neovim (latest stable from GitHub releases — apt version is often outdated)
  if ! command_exists nvim || [[ "$(nvim --version | head -1 | grep -oP '\d+\.\d+')" < "0.10" ]]; then
    info "Installing Neovim from GitHub releases..."
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    curl -fsSL "$NVIM_URL" | sudo tar xz -C /opt
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  fi

  # fzf
  if ! command_exists fzf; then
    info "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
    "${HOME}/.fzf/install" --all --no-bash --no-fish
  fi

  # Starship
  if ! command_exists starship; then
    info "Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
  fi

  # Zellij
  if ! command_exists zellij; then
    info "Installing Zellij..."
    ZELLIJ_URL=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
      | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64-unknown-linux-musl[^"]*\.tar\.gz')
    curl -fsSL "$ZELLIJ_URL" | tar xz -C /tmp
    sudo install /tmp/zellij /usr/local/bin/zellij
  fi

  # Nerd Font (CaskaydiaCove)
  FONT_DIR="${HOME}/.local/share/fonts"
  if [ ! -f "${FONT_DIR}/CaskaydiaCoveNerdFont-Regular.ttf" ]; then
    info "Installing CaskaydiaCove Nerd Font..."
    mkdir -p "$FONT_DIR"
    FONT_URL=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
      | grep -oP '"browser_download_url":\s*"\K[^"]*CascadiaCode\.tar\.xz')
    curl -fsSL "$FONT_URL" | tar xJ -C "$FONT_DIR"
    fc-cache -f "$FONT_DIR"
  fi

  # Neovide (GUI for Neovim) — x86_64 prebuilt tarball from GitHub releases
  if ! command_exists neovide; then
    ARCH="$(uname -m)"
    if [[ "$ARCH" == "x86_64" ]]; then
      info "Installing Neovide from GitHub releases..."
      NEOVIDE_URL=$(curl -fsSL https://api.github.com/repos/neovide/neovide/releases/latest \
        | grep -oP '"browser_download_url":\s*"\K[^"]*neovide-linux-x86_64\.tar\.gz')
      if [[ -n "$NEOVIDE_URL" ]]; then
        mkdir -p "${HOME}/.local/bin"
        TMP_NEOVIDE="$(mktemp -d)"
        curl -fsSL "$NEOVIDE_URL" | tar xz -C "$TMP_NEOVIDE"
        # Tarball ships a single `neovide` binary (sometimes nested in a dir)
        NEOVIDE_BIN="$(find "$TMP_NEOVIDE" -type f -name neovide | head -1)"
        if [[ -n "$NEOVIDE_BIN" ]]; then
          install -m 0755 "$NEOVIDE_BIN" "${HOME}/.local/bin/neovide"
        else
          warn "Could not locate neovide binary in downloaded archive — skipping"
        fi
        rm -rf "$TMP_NEOVIDE"
      else
        warn "Could not resolve Neovide download URL — skipping"
      fi
    else
      warn "Neovide prebuilt binary not available for arch '${ARCH}' — skipping"
    fi
  fi

  ok "Ubuntu/Debian packages installed"
}

# ---------------------------------------------------------------------------
# Clone / update dotfiles repo
# ---------------------------------------------------------------------------
setup_dotfiles_repo() {
  if [ -d "${DOTFILES_DIR}/.git" ]; then
    info "Updating dotfiles repo..."
    git -C "$DOTFILES_DIR" pull --rebase --quiet
  else
    info "Cloning dotfiles repo..."
    if command_exists git; then
      git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
      err "git is not installed and could not be bootstrapped"
    fi
  fi
  ok "Dotfiles repo ready at ${DOTFILES_DIR}"
}

# ---------------------------------------------------------------------------
# Symlink helper
# ---------------------------------------------------------------------------
link_file() {
  local src="$1" dst="$2"
  # Back up existing file/dir if it's not already a symlink to us
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.backup.$(date +%Y%m%d%H%M%S)"
    warn "Backing up existing ${dst} → ${backup}"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  ok "Linked ${dst} → ${src}"
}

create_symlinks() {
  info "Creating symlinks..."
  link_file "${DOTFILES_DIR}/nvim"                  "${HOME}/.config/nvim"
  link_file "${DOTFILES_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"
  link_file "${DOTFILES_DIR}/zellij/config.kdl"      "${HOME}/.config/zellij/config.kdl"
  link_file "${DOTFILES_DIR}/zsh/.zshrc"             "${HOME}/.zshrc"

  # Neovide config (respects XDG_CONFIG_HOME on Linux; macOS uses ~/.config)
  NEOVIDE_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/neovide"
  link_file "${DOTFILES_DIR}/neovide/config.toml"    "${NEOVIDE_CONFIG_DIR}/config.toml"

  # AI agent instructions (shared by Copilot CLI and opencode)
  link_file "${DOTFILES_DIR}/ai/instructions.md" "${HOME}/.copilot/copilot-instructions.md"
  link_file "${DOTFILES_DIR}/ai/instructions.md" "${HOME}/.config/opencode/AGENTS.md"
}

# ---------------------------------------------------------------------------
# Set default shell to zsh
# ---------------------------------------------------------------------------
set_default_shell() {
  if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    chsh -s "$(which zsh)" || warn "Could not change shell — run: chsh -s \$(which zsh)"
  fi
  ok "Default shell: zsh"
}

# ===========================================================================
# Main
# ===========================================================================
main() {
  info "Starting dotfiles setup..."
  detect_os

  case "$OS" in
    macos)  install_packages_macos  ;;
    debian) install_packages_debian ;;
    *)      warn "Unsupported distro — install packages manually, then re-run." ;;
  esac

  setup_dotfiles_repo
  create_symlinks
  set_default_shell

  echo ""
  ok "✨ Dotfiles setup complete!"
  info "Open a new terminal to start using your config."
  info "Neovim will auto-install plugins on first launch — just run: nvim"
}

main "$@"
