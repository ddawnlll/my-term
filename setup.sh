#!/usr/bin/env bash
# ============================================================================
#  🌸 my-term Setup  —  Kitty + Starship + Oh My Zsh + Waifu Greeting
#  Idempotent: safe to run multiple times.
# ============================================================================
set -euo pipefail

CUSER="${SUDO_USER:-$USER}"
CHOME="$(eval echo "~$CUSER")"
LOCAL_BIN="$CHOME/.local/bin"
ZSH_CUSTOM="${ZSH_CUSTOM:-$CHOME/.oh-my-zsh/custom}"
KITTY_DIR="$CHOME/.local/kitty"
KITTY_CONF_DIR="$CHOME/.config/kitty"
FONT_DIR="$CHOME/.local/share/fonts"
WAIFU_CACHE="$CHOME/.cache/waifu-greeting"
REPO="$(cd "$(dirname "$0")" && pwd)"

RESET='\033[0m'; BOLD='\033[1m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; MAGENTA='\033[0;35m'

info()  { echo -e " ${CYAN}◆${RESET}  $1"; }
ok()    { echo -e " ${GREEN}✔${RESET}  $1"; }
warn()  { echo -e " ${YELLOW}⚠${RESET}  $1"; }
err()   { echo -e " ${RED}✘${RESET}  $1"; }
header(){ echo; echo -e "${BOLD}${MAGENTA}━━ $1 ──${RESET}"; }

# ── package manager ──────────────────────────────────────────────────
PM=""
command -v apt &>/dev/null && PM="apt"
command -v pacman &>/dev/null && PM="pacman"
command -v dnf &>/dev/null && PM="dnf"
command -v brew &>/dev/null && PM="brew"

install_pkg() {
    local pkg="$1"
    [ -z "$PM" ] && return 1
    case "$PM" in
        apt)    sudo apt install -y "$pkg" 2>/dev/null ;;
        pacman) sudo pacman -S --noconfirm "$pkg" 2>/dev/null ;;
        dnf)    sudo dnf install -y "$pkg" 2>/dev/null ;;
        brew)   brew install "$pkg" 2>/dev/null ;;
    esac && return 0
    return 1
}

mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$PATH"

# ── 1. Shell ─────────────────────────────────────────────────────────
header "Zsh"
if command -v zsh &>/dev/null; then
    ok "zsh $(zsh --version 2>/dev/null | head -1)"
else
    install_pkg zsh || { err "install zsh manually"; exit 1; }
fi
[ "$SHELL" != "$(which zsh)" ] && chsh -s "$(which zsh)" 2>/dev/null && ok "default shell → zsh" || warn "run: chsh -s $(which zsh)"

# ── 2. Oh My Zsh ─────────────────────────────────────────────────────
header "Oh My Zsh"
if [ -d "$CHOME/.oh-my-zsh" ]; then
    ok "already installed"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1
    ok "installed"
fi

install_plugin() {
    local name="$1" url="$2" dir="$3"
    if [ -d "$dir" ]; then ok "plugin $name exists"
    else git clone --depth 1 "$url" "$dir" 2>/dev/null && ok "plugin $name installed" || warn "plugin $name failed"
    fi
}
install_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ── 3. Starship ──────────────────────────────────────────────────────
header "Starship Prompt"
SB="$LOCAL_BIN/starship"
if [ -x "$SB" ]; then
    ok "starship $($SB --version 2>/dev/null)"
else
    curl -sSLO "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf starship-x86_64-unknown-linux-musl.tar.gz -C "$LOCAL_BIN" starship
    rm starship-x86_64-unknown-linux-musl.tar.gz; chmod +x "$SB"
    ok "starship installed"
fi

# ── 4. Kitty Terminal ────────────────────────────────────────────────
header "Kitty Terminal"
KITTY_BIN="$KITTY_DIR/bin/kitty"
if [ -x "$KITTY_BIN" ]; then
    ok "kitty $($KITTY_BIN --version 2>/dev/null)"
else
    local ver url tmpdir
    tmpdir="$(mktemp -d)"
    ver="$(curl -sI https://github.com/kovidgoyal/kitty/releases/latest | grep -i '^location:' | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || ver="v0.47.4"
    url="https://github.com/kovidgoyal/kitty/releases/download/$ver/kitty-${ver#v}-x86_64.txz"
    curl -sSL "$url" -o "$tmpdir/kitty.txz" && \
    mkdir -p "$KITTY_DIR/bin" "$KITTY_DIR/lib" "$KITTY_DIR/share" && \
    tar -xJf "$tmpdir/kitty.txz" -C "$tmpdir" && \
    cp "$tmpdir/bin/kitty" "$KITTY_DIR/bin/kitty" && \
    cp "$tmpdir/bin/kitten" "$KITTY_DIR/bin/kitten" && \
    chmod +x "$KITTY_DIR/bin/kitty" "$KITTY_DIR/bin/kitten" && \
    cp -r "$tmpdir/lib/"* "$KITTY_DIR/lib/" && \
    cp -r "$tmpdir/share/"* "$KITTY_DIR/share/" && \
    rm -rf "$tmpdir" && ok "kitty $ver installed" || warn "kitty install failed"
fi

# Kitty wrapper
if [ ! -f "$LOCAL_BIN/kitty" ] && [ -x "$KITTY_BIN" ]; then
    echo '#!/bin/bash' > "$LOCAL_BIN/kitty"
    echo 'exec "$HOME/.local/kitty/bin/kitty" "$@"' >> "$LOCAL_BIN/kitty"
    chmod +x "$LOCAL_BIN/kitty"
fi

# Kitty config with anime wallpaper support
mkdir -p "$KITTY_CONF_DIR/wallpaper"
if [ ! -f "$KITTY_CONF_DIR/kitty.conf" ]; then
    cat > "$KITTY_CONF_DIR/kitty.conf" << 'KITTYCONF'
font_size 12.0
background_opacity 0.95
window_padding_width 8
shell zsh
tab_bar_style powerline
tab_powerline_style round
cursor_trail 3
cursor_trail_start_threshold 5
KITTYCONF
    ok "kitty.conf written"
fi

# ── 5. Waifu Greeting ───────────────────────────────────────────────
header "Waifu Greeting"
GREETING="$LOCAL_BIN/neko-greeting"
if [ -f "$GREETING" ]; then
    ok "greeting script exists"
else
    if [ -f "$REPO/neko-greeting.py" ]; then
        cp "$REPO/neko-greeting.py" "$GREETING"
    else
        curl -fsSL "https://raw.githubusercontent.com/yukaraca/my-term/main/neko-greeting.py" -o "$GREETING" 2>/dev/null || {
            warn "downloading greeting script..."
            # Fallback: embed minimal version
            cat > "$GREETING" << 'EMBED'
#!/usr/bin/env python3
# Waifu Greeting — full version at github.com/yukaraca/my-term
import os, sys, random, json, shutil, hashlib, time, base64, subprocess
from pathlib import Path; from datetime import datetime
from urllib.request import urlopen, Request
CDIR=os.path.expanduser("~/.cache/waifu-greeting"); API="https://nekos.best/api/v2/{e}"
EPS=["waifu","neko","smile","kitsune"]
def fu():
    try:
        d=json.loads(urlopen(Request(API.format(e=random.choice(EPS)),headers={"User-Agent":"greeting/1.0","Accept":"application/json"}),timeout=10).read())
        return d["results"][0]["url"]
    except: return None
def gc():
    p=Path(CDIR)
    if not p.exists(): return []
    return sorted([f for f in p.iterdir() if f.suffix.lower() in (".png",".jpg",".jpeg",".webp",".gif") and f.is_file()], key=lambda x:x.name)
def di(p):
    try:
        if "kitty" not in os.environ.get("TERM","").lower() and not os.environ.get("KITTY_WINDOW_ID"): return False
        k=shutil.which("kitten") or os.path.expanduser("~/.local/kitty/bin/kitten")
        if not os.path.exists(k): return False
        c,l=shutil.get_terminal_size()
        p2=subprocess.Popen([k,"icat","--transfer-mode=file","--stdin=no","--use-window-size",f"{c},{l},{c*14},{l*28}","--align","center",str(p)],stdin=subprocess.DEVNULL,stdout=sys.stdout,stderr=sys.stderr,start_new_session=True)
        p2.wait(); return p2.returncode==0
    except: return False
def gr():
    h=datetime.now().hour
    if h<12: return random.choice(["✨ Ohayou! ✨","🌅 Good morning! ✨"])
    elif h<17: return random.choice(["✨ Konnichiwa! ✨","🌞 Hello! ✨"])
    elif h<22: return random.choice(["✨ Konbanwa! ✨","🌆 Good evening! ✨"])
    else: return random.choice(["✨ Oyasumi... ✨","🌙 Late night? ✨"])
def main():
    if os.environ.get("NEKO_SKIP") or os.environ.get("WAIFU_SKIP"): return
    im=gc()
    if im:
        idx=int((Path(CDIR)/".index").read_text().strip() or "0") if (Path(CDIR)/".index").exists() else 0
        di(im[idx%len(im)]); (Path(CDIR)/".index").write_text(str(idx+1))
    w=shutil.get_terminal_size().columns; print(f"\n{gr():^{w}}\n")
if __name__=="__main__": main()
EMBED
        }
    fi
    chmod +x "$GREETING" && ok "greeting script created" || err "failed to create greeting script"
fi

# ── 6. .zshrc ────────────────────────────────────────────────────────
header ".zshrc"
ZSHRC="$CHOME/.zshrc"
[ -f "$ZSHRC" ] && cp "$ZSHRC" "$ZSHRC.bak" 2>/dev/null
cat > "$ZSHRC" << 'ZSHEOF'
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git sudo command-not-found web-search colored-man-pages history zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
bindkey '^ ' autosuggest-accept
bindkey '^[[C' autosuggest-accept
bindkey '^[[Z' reverse-menu-complete
alias ll='ls -lah'; alias la='ls -A'; alias l='ls -CF'
alias ..='cd ..'; alias ...='cd ../..'
alias c='clear'; alias h='history'
alias v='nvim'; alias vi='nvim'; alias vim='nvim'
alias reload='source ~/.zshrc'
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{green}--> %d%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache yes
if command -v eza &>/dev/null; then alias ls='eza --icons'; alias ll='eza -lah --icons'
elif command -v exa &>/dev/null; then alias ls='exa --icons'; alias ll='exa -lah --icons'
fi
if command -v fzf &>/dev/null; then
  source ~/.fzf/shell/key-bindings.zsh 2>/dev/null || source /usr/share/fzf/key-bindings.zsh 2>/dev/null || true
fi
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(starship init zsh)"
if [[ -z "${NEKO_SKIP:-}" && -z "${WAIFU_SKIP:-}" && -z "${SSH_CONNECTION:-}" && -t 0 ]]; then
  neko-greeting
fi
ZSHEOF
ok ".zshrc written"

# ── 7. Done ──────────────────────────────────────────────────────────
header "Done!"
echo
echo -e "  ${GREEN}✔${RESET}  Kitty:     ${CYAN}$KITTY_BIN${RESET}"
echo -e "  ${GREEN}✔${RESET}  Greeting:  ${CYAN}$GREETING${RESET}"
echo -e "  ${GREEN}✔${RESET}  .zshrc:    ${CYAN}$ZSHRC${RESET}"
echo
echo -e "  ${YELLOW}➜${RESET}  Open a ${BOLD}new Kitty terminal${RESET} to see your waifu! 🖼️"
echo -e "  ${YELLOW}➜${RESET}  Run: ${CYAN}python3 ~/.local/bin/neko-greeting${RESET}"
echo -e "  ${YELLOW}➜${RESET}  Skip: ${CYAN}WAIFU_SKIP=1 zsh${RESET}"
echo
