#!/usr/bin/env zsh
# ~/.zshrc — managed by dotfiles

# ---------------------------------------------------------------------------
# Plugin manager (manual, no framework)
# ---------------------------------------------------------------------------
ZSH_PLUGIN_DIR="${HOME}/.local/share/zsh/plugins"

_ensure_plugin() {
  local repo="$1" name="${1##*/}"
  if [[ ! -d "${ZSH_PLUGIN_DIR}/${name}" ]]; then
    echo "Installing zsh plugin: ${name}..."
    git clone --depth=1 "https://github.com/${repo}.git" "${ZSH_PLUGIN_DIR}/${name}"
  fi
  source "${ZSH_PLUGIN_DIR}/${name}/${name}.zsh" 2>/dev/null \
    || source "${ZSH_PLUGIN_DIR}/${name}/${name}.plugin.zsh" 2>/dev/null
}

_ensure_plugin zsh-users/zsh-autosuggestions
_ensure_plugin zsh-users/zsh-syntax-highlighting

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY HIST_REDUCE_BLANKS APPEND_HISTORY INC_APPEND_HISTORY

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
autoload -Uz compinit && compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ---------------------------------------------------------------------------
# Key bindings
# ---------------------------------------------------------------------------
bindkey -e                           # emacs mode
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ---------------------------------------------------------------------------
# fzf integration
# ---------------------------------------------------------------------------
if command -v fzf &>/dev/null; then
  # fzf 0.48+ ships a built-in shell integration
  if [[ -f "${HOME}/.fzf.zsh" ]]; then
    source "${HOME}/.fzf.zsh"
  else
    eval "$(fzf --zsh 2>/dev/null)" || true
  fi
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias vi='nvim'
alias vim='nvim'
alias ll='ls -lAh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias copilot='copilot --yolo'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'

# ---------------------------------------------------------------------------
# PATH additions
# ---------------------------------------------------------------------------
typeset -U path
path=(${HOME}/.local/bin ${HOME}/.cargo/bin $path)

# ---------------------------------------------------------------------------
# Starship prompt (load last)
# ---------------------------------------------------------------------------
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi
