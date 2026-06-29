# ── my-term .zshrc ──────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(
  git sudo command-not-found web-search colored-man-pages
  history zsh-autosuggestions zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ── Keybindings ─────────────────────────────────────────────────────────────
bindkey '^ ' autosuggest-accept
bindkey '^[[C' autosuggest-accept
bindkey '^[[Z' reverse-menu-complete

# ── Aliases ─────────────────────────────────────────────────────────────────
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias reload='source ~/.zshrc'

# ── Completion ──────────────────────────────────────────────────────────────
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{green}--> %d%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache yes

# ── Modern ls replacements ──────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lah --icons'
elif command -v exa &>/dev/null; then
  alias ls='exa --icons'
  alias ll='exa -lah --icons'
fi

# ── fzf ─────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  source ~/.fzf/shell/key-bindings.zsh 2>/dev/null \
    || source /usr/share/fzf/key-bindings.zsh 2>/dev/null \
    || true
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ── Starship ────────────────────────────────────────────────────────────────
eval "$(starship init zsh)"

# ── Waifu Greeting ─────────────────────────────────────────────────────────
if [[ -z "${NEKO_SKIP:-}" && -z "${WAIFU_SKIP:-}" && -z "${SSH_CONNECTION:-}" && -t 0 ]]; then
  neko-greeting
fi
