#!/usr/bin/env bash
# ============================================================================
#  🌸 my-term Setup  v2.0
#  Kitty + Starship + Oh My Zsh + Waifu Greeting
#
#  Idempotent  ·  Parallel downloads  ·  Arch-aware
#  Safe to re-run; backs up configs before touching.
#
#  Usage:
#    ./setup.sh          →  launches interactive TUI (recommended)
#    ./setup.sh --no-tui →  runs the classic bash installer
# ============================================================================
set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────
SCRIPT_NAME="${0##*/}"
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
DIM='\033[2m'

# ── Flags (set by CLI parser) ──────────────────────────────────────────────
DO_KITTY=true
DO_WAIFU=true
DO_ZSH=true
DO_STARSHIP=true
UNATTENDED=false

# ── Helpers ────────────────────────────────────────────────────────────────
info()  { echo -e " ${CYAN}◇${RESET}  $1"; }
ok()    { echo -e " ${GREEN}✔${RESET}  $1"; }
warn()  { echo -e " ${YELLOW}⚠${RESET}  $1"; }
err()   { echo -e " ${RED}✘${RESET}  $1"; }
header(){ echo; echo -e "${BOLD}${MAGENTA}━━ $1 ──${RESET}"; }
sub()   { echo -e "   ${DIM}→${RESET}  $1"; }

# ── Package manager detection ──────────────────────────────────────────────
detect_pm() {
    local pm="" candidate
    for candidate in apt pacman dnf brew zypper apk; do
        command -v "$candidate" &>/dev/null && { pm="$candidate"; break; }
    done
    echo "$pm"
}

install_pkg() {
    local pkg="$1" pm; pm="$(detect_pm)"
    [ -z "$pm" ] && return 1
    sub "installing ${pkg} via ${pm} …"
    case "$pm" in
        apt)    DEBIAN_FRONTEND=noninteractive sudo apt install -y "$pkg" 2>/dev/null ;;
        pacman) sudo pacman -S --noconfirm "$pkg" 2>/dev/null ;;
        dnf)    sudo dnf install -y "$pkg" 2>/dev/null ;;
        brew)   brew install "$pkg" 2>/dev/null ;;
        zypper) sudo zypper install -y "$pkg" 2>/dev/null ;;
        apk)    sudo apk add "$pkg" 2>/dev/null ;;
    esac && return 0
    return 1
}

# ── Spinner (braille dots, no cursor flicker) ──────────────────────────────
spinner() {
    local pid=$1 msg=$2 chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r   ${DIM}${chars[i]}${RESET}  ${msg} …"
        i=$(( (i + 1) % ${#chars[@]} ))
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    echo -ne "\r${DIM}                                                                      ${RESET}\r"
    return $?
}

# ── Pre-flight checks ─────────────────────────────────────────────────────
preflight() {
    header "Pre-flight"

    # Cache sudo up-front so we don't prompt mid-install
    if command -v sudo &>/dev/null; then
        if ! sudo -n true 2>/dev/null; then
            if [ -t 1 ]; then
                info "sudo needed for package installs …"
                sudo -v
                # Keep sudo alive in background
                while true; do sudo -n true; sleep 60; done 2>/dev/null &
            else
                warn "sudo required for package installs (non-TTY)"
            fi
        fi
    fi

    # Internet connectivity
    if command -v curl &>/dev/null; then
        if ! curl -sS --max-time 5 https://github.com >/dev/null 2>&1; then
            err "no internet connectivity  —  some downloads may fail"
        else
            ok "internet reachable"
        fi
    fi

    # Arch detection for binary downloads
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  ARCH_SUFFIX="x86_64" ;;
        aarch64|arm64) ARCH_SUFFIX="aarch64" ;;
        *) warn "unsupported arch ${arch} for auto-install" ;;
    esac

    mkdir -p "$LOCAL_BIN"
    export PATH="$LOCAL_BIN:$PATH"
}

# ── 1. Shell ──────────────────────────────────────────────────────────────
setup_zsh() {
    $DO_ZSH || return 0
    header "Zsh"

    if command -v zsh &>/dev/null; then
        ok "zsh $(zsh --version 2>/dev/null | head -1)"
    else
        install_pkg zsh || { err "install zsh manually first (e.g. sudo apt install zsh)"; return 1; }
    fi

    local zsh_path
    zsh_path="$(command -v zsh)" || true
    if [ -n "$zsh_path" ] && [ "$SHELL" != "$zsh_path" ]; then
        if $UNATTENDED; then
            warn "run: chsh -s ${zsh_path}"
        else
            chsh -s "$zsh_path" 2>/dev/null && ok "default shell → zsh" || warn "run: chsh -s ${zsh_path}"
        fi
    elif [ "$SHELL" = "$zsh_path" ]; then
        ok "default shell already zsh"
    fi
}

# ── 2. Oh My Zsh ──────────────────────────────────────────────────────────
setup_omz() {
    $DO_ZSH || return 0
    header "Oh My Zsh"

    if [ -d "$CHOME/.oh-my-zsh" ]; then
        ok "already installed"
    else
        info "installing Oh My Zsh …"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1
        ok "installed"
    fi

    install_plugin "zsh-autosuggestions" \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

    install_plugin "zsh-syntax-highlighting" \
        "https://github.com/zsh-users/zsh-syntax-highlighting" \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
}

install_plugin() {
    local name="$1" url="$2" dir="$3"
    if [ -d "$dir" ]; then
        ok "plugin ${name} exists"
    else
        sub "cloning ${name} …"
        git clone --depth 1 --quiet "$url" "$dir" 2>/dev/null && ok "plugin ${name} installed" || warn "plugin ${name} failed"
    fi
}

# ── 3. Starship ────────────────────────────────────────────────────────────
setup_starship() {
    $DO_STARSHIP || return 0
    header "Starship Prompt"

    local starship_bin="$LOCAL_BIN/starship"
    if [ -x "$starship_bin" ]; then
        ok "starship $($starship_bin --version 2>/dev/null)"
        return 0
    fi

    # Try the official install script first (fast, auto-detects arch)
    if command -v curl &>/dev/null; then
        sub "downloading starship …"
        if curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN" 2>/dev/null; then
            ok "starship installed via script"
            return 0
        fi
    fi

    # Fallback: manual binary download
    local arch_ts ver url
    arch_ts="$(uname -m)"
    case "$arch_ts" in
        x86_64)  arch_ts="x86_64-unknown-linux-musl" ;;
        aarch64|arm64) arch_ts="aarch64-unknown-linux-musl" ;;
        *) arch_ts="x86_64-unknown-linux-musl" ;;
    esac

    ver="$(curl -sI https://github.com/starship/starship/releases/latest 2>/dev/null \
           | grep -i '^location:' | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || ver=""
    [ -z "$ver" ] && ver="v1.17.1"

    url="https://github.com/starship/starship/releases/download/${ver}/starship-${arch_ts}.tar.gz"
    sub "downloading ${ver} (${arch_ts}) …"

    curl -sSL "$url" -o /tmp/starship.tar.gz && \
    tar -xzf /tmp/starship.tar.gz -C "$LOCAL_BIN" starship && \
    rm -f /tmp/starship.tar.gz && \
    chmod +x "$starship_bin" && ok "starship installed" || warn "starship install failed"
}

# ── Distro detection ─────────────────────────────────────────────────────
is_arch_like() {
    [ -f /etc/os-release ] && grep -qi '^ID_LIKE=.*arch\|^ID=arch\|^ID=cachyos\|^ID=endeavouros\|^ID=manjaro\|^ID=garuda' /etc/os-release
}

# ── Desktop database refresh ──────────────────────────────────────────────
refresh_desktop_db() {
    sub "refreshing desktop application database …"
    if command -v update-desktop-database &>/dev/null; then
        sudo update-desktop-database 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache &>/dev/null; then
        sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
    fi
    if command -v xdg-desktop-menu &>/dev/null; then
        xdg-desktop-menu forceupdate 2>/dev/null || true
    fi
    ok "app list refreshed"
}

# ── 4. Kitty Terminal ──────────────────────────────────────────────────────
setup_kitty() {
    $DO_KITTY || return 0
    header "Kitty Terminal"

    # ── Arch Linux → pacman install (proper system integration) ──────────
    if is_arch_like; then
        info "Arch-based distro detected — using pacman for system integration"
        if command -v kitty &>/dev/null; then
            ok "kitty $($(command -v kitty) --version 2>/dev/null) (system package)"
            setup_kitty_config
            refresh_desktop_db
            return 0
        fi
        if command -v pacman &>/dev/null; then
            sub "installing kitty via pacman …"
            sudo pacman -S --noconfirm kitty 2>&1 && {
                ok "kitty installed (system package)"
                setup_kitty_config
                refresh_desktop_db
                return 0
            }
            warn "pacman install failed — falling back to binary"
        fi
    fi

    # ── Portable binary install (non-Arch or pacman failed) ──────────────
    local kitty_bin="$KITTY_DIR/bin/kitty"
    if [ -x "$kitty_bin" ]; then
        ok "kitty $($kitty_bin --version 2>/dev/null) (portable)"
        setup_kitty_config
        return 0
    fi

    if [ -z "${ARCH_SUFFIX:-}" ]; then
        warn "kitty binary install unavailable for this arch — install manually"
        setup_kitty_config
        return 0
    fi

    # Fetch latest version
    local ver url
    ver="$(curl -sI https://github.com/kovidgoyal/kitty/releases/latest 2>/dev/null \
           | grep -i '^location:' | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || ver=""
    [ -z "$ver" ] && ver="v0.37.0"

    url="https://github.com/kovidgoyal/kitty/releases/download/${ver}/kitty-${ver#v}-${ARCH_SUFFIX}.txz"

    info "downloading ${ver} (${ARCH_SUFFIX}) …"
    local tmpdir
    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT

    if curl -sSL "$url" -o "$tmpdir/kitty.txz" 2>/dev/null; then
        mkdir -p "$KITTY_DIR/bin" "$KITTY_DIR/lib" "$KITTY_DIR/share"
        tar -xJf "$tmpdir/kitty.txz" -C "$tmpdir"
        cp "$tmpdir/bin/kitty" "$KITTY_DIR/bin/kitty"
        cp "$tmpdir/bin/kitten" "$KITTY_DIR/bin/kitten"
        chmod +x "$KITTY_DIR/bin/kitty" "$KITTY_DIR/bin/kitten"
        cp -r "$tmpdir/lib/"* "$KITTY_DIR/lib/" 2>/dev/null || true
        cp -r "$tmpdir/share/"* "$KITTY_DIR/share/" 2>/dev/null || true
        rm -rf "$tmpdir"
        trap - EXIT
        ok "kitty ${ver} installed (portable)"

        # Create desktop entry for portable install so it shows in app list
        local desktop_dir="${XDG_DATA_HOME:-$CHOME/.local/share}/applications"
        mkdir -p "$desktop_dir"
        if [ ! -f "$desktop_dir/kitty.desktop" ]; then
            cat > "$desktop_dir/kitty.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Kitty
Comment=Fast, feature-rich GPU-based terminal emulator
Exec=$KITTY_DIR/bin/kitty
Icon=kitty
Terminal=false
Categories=System;TerminalEmulator;
StartupWMClass=kitty
Keywords=terminal;console;shell;emulator;
DESKTOP
            chmod +x "$desktop_dir/kitty.desktop"
            sub "created desktop entry for portable install"
        fi
    else
        rm -rf "$tmpdir"
        trap - EXIT
        warn "kitty binary install failed — install manually from https://github.com/kovidgoyal/kitty/releases"
    fi

    # Kitty wrapper script in PATH
    if [ -x "$kitty_bin" ] && [ ! -f "$LOCAL_BIN/kitty" ]; then
        cat > "$LOCAL_BIN/kitty" << 'WRAPPER'
#!/bin/bash
exec "$HOME/.local/kitty/bin/kitty" "$@"
WRAPPER
        chmod +x "$LOCAL_BIN/kitty"
    fi

    setup_kitty_config
    refresh_desktop_db
}

setup_kitty_config() {
    mkdir -p "$KITTY_CONF_DIR/wallpaper"

    # Deploy Catppuccin rice configs from repo
    local repo_configs="$REPO/configs/kitty"
    if [ -d "$repo_configs" ]; then
        if [ -f "$KITTY_CONF_DIR/kitty.conf" ]; then
            local backup="${KITTY_CONF_DIR}/kitty.conf.bak.$(date +%s)"
            cp "$KITTY_CONF_DIR/kitty.conf" "$backup" && sub "backed up existing kitty.conf → $(basename "$backup")"
        fi
        cp "$repo_configs/catppuccin-mocha.conf" "$KITTY_CONF_DIR/catppuccin-mocha.conf"
        cp "$repo_configs/kitty.conf" "$KITTY_CONF_DIR/kitty.conf"
        ok "kitty rice deployed (Catppuccin Mocha + Iosevka)"
    else
        # Fallback: write minimal config if repo configs missing
        cat > "$KITTY_CONF_DIR/kitty.conf" << 'KITTYCONF'
# my-term kitty configuration
font_size 12.0
background_opacity 0.95
window_padding_width 8
shell zsh
tab_bar_style powerline
tab_powerline_style round
cursor_trail 3
cursor_trail_start_threshold 5
KITTYCONF
        ok "kitty.conf written (fallback)"
    fi
}

# ── 5. Iosevka Nerd Font ─────────────────────────────────────────────────
setup_font() {
    header "Iosevka Nerd Font"

    if fc-list 2>/dev/null | grep -qi "iosevka"; then
        ok "Iosevka Nerd Font found"
        return 0
    fi

    info "installing Iosevka Nerd Font …"
    if is_arch_like && command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm ttf-iosevka-nerd 2>&1 && ok "Iosevka Nerd Font installed" || warn "font install failed"
    else
        warn "install ttf-iosevka-nerd manually for your distro"
    fi
}

# ── 6. Waifu Greeting ──────────────────────────────────────────────────────
setup_waifu() {
    $DO_WAIFU || return 0
    header "Waifu Greeting"

    local greeting_bin="$LOCAL_BIN/neko-greeting"
    if [ -f "$greeting_bin" ]; then
        ok "greeting script exists"
        return 0
    fi

    mkdir -p "$LOCAL_BIN"

    # Prefer local repository copy
    if [ -f "$REPO/neko-greeting.py" ]; then
        cp "$REPO/neko-greeting.py" "$greeting_bin"
        chmod +x "$greeting_bin"
        ok "greeting script copied from repo"
        return 0
    fi

    # Try remote, fall back to embedded
    if command -v curl &>/dev/null; then
        sub "downloading greeting script …"
        if curl -fsSL "https://raw.githubusercontent.com/yukaraca/my-term/main/neko-greeting.py" -o "$greeting_bin" 2>/dev/null; then
            chmod +x "$greeting_bin" && ok "greeting script downloaded"
            return 0
        fi
    fi

    # Embedded fallback — fully self-contained
    info "embedding minimal greeting script …"
    cat > "$greeting_bin" << 'EMBED'
#!/usr/bin/env python3
"""neko-greeting — displays a random waifu image via Kitty icat, plus a time-aware greeting."""
import os, sys, random, json, shutil, hashlib, time, base64, subprocess
from pathlib import Path
from datetime import datetime
from urllib.request import urlopen, Request

CDIR = os.path.expanduser("~/.cache/waifu-greeting")
API_URL = "https://nekos.best/api/v2/{e}"
ENDPOINTS = ["waifu", "neko", "smile", "kitsune"]
USER_AGENT = "my-term-greeting/1.0"


def fetch_image_url():
    """Fetch a random waifu image URL from the API."""
    try:
        ep = random.choice(ENDPOINTS)
        req = Request(API_URL.format(e=ep), headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        data = json.loads(urlopen(req, timeout=10).read())
        return data["results"][0]["url"]
    except Exception:
        return None


def get_cached_images():
    """Return sorted list of cached waifu images."""
    p = Path(CDIR)
    if not p.exists():
        return []
    exts = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
    return sorted([f for f in p.iterdir() if f.suffix.lower() in exts and f.is_file()], key=lambda x: x.name)


def display_image(path):
    """Display an image using Kitty's icat protocol."""
    try:
        term = os.environ.get("TERM", "").lower()
        if "kitty" not in term and not os.environ.get("KITTY_WINDOW_ID"):
            return False
        kitten = shutil.which("kitten") or os.path.expanduser("~/.local/kitty/bin/kitten")
        if not os.path.exists(kitten):
            return False
        cols, lines = shutil.get_terminal_size()
        proc = subprocess.Popen(
            [kitten, "icat", "--transfer-mode=file", "--stdin=no",
             "--use-window-size", f"{cols},{lines},{cols*14},{lines*28}",
             "--align", "center", str(path)],
            stdin=subprocess.DEVNULL, stdout=sys.stdout, stderr=sys.stderr,
            start_new_session=True,
        )
        proc.wait()
        return proc.returncode == 0
    except Exception:
        return False


def greeting():
    h = datetime.now().hour
    if h < 6:
        return random.choice(["🌙 Oyasumi...", "🦉 Late night?"])
    elif h < 12:
        return random.choice(["✨ Ohayou! ✨", "🌅 Good morning! ✨"])
    elif h < 17:
        return random.choice(["✨ Konnichiwa! ✨", "☀️ Hello! ✨"])
    elif h < 22:
        return random.choice(["✨ Konbanwa! ✨", "🌆 Good evening! ✨"])
    else:
        return random.choice(["✨ Oyasumi... ✨", "🌙 Late night? ✨"])


def main():
    if os.environ.get("NEKO_SKIP") or os.environ.get("WAIFU_SKIP"):
        return

    images = get_cached_images()
    if images:
        idx_file = Path(CDIR) / ".index"
        idx = int(idx_file.read_text().strip() or "0") if idx_file.exists() else 0
        display_image(images[idx % len(images)])
        idx_file.write_text(str(idx + 1))

    width = shutil.get_terminal_size().columns
    print(f"\n{greeting():^{width}}\n")


if __name__ == "__main__":
    main()
EMBED
    chmod +x "$greeting_bin" && ok "greeting script created (embedded)" \
        || err "failed to create greeting script"
}

# ── 6. .zshrc ──────────────────────────────────────────────────────────────
setup_zshrc() {
    $DO_ZSH || return 0
    header ".zshrc"

    local zshrc="$CHOME/.zshrc"

    # Backup existing .zshrc with timestamp
    if [ -f "$zshrc" ]; then
        cp "$zshrc" "${zshrc}.bak.$(date +%s)" 2>/dev/null
        ok "existing .zshrc backed up"
    fi

    cat > "$zshrc" << 'ZSHEOF'
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
ZSHEOF
    ok ".zshrc written"
}

# ── Summary ─────────────────────────────────────────────────────────────────
show_summary() {
    header "Done!"
    echo
    echo -e "  ${GREEN}✔${RESET}  Kitty:     ${CYAN}Catppuccin Mocha + Iosevka rice${RESET}"
    echo -e "  ${GREEN}✔${RESET}  Font:      ${CYAN}Iosevka Nerd Font${RESET}"
    echo -e "  ${GREEN}✔${RESET}  Greeting:  ${CYAN}$LOCAL_BIN/neko-greeting${RESET}"
    echo -e "  ${GREEN}✔${RESET}  .zshrc:    ${CYAN}$CHOME/.zshrc${RESET}"
    echo
    echo -e "  ${YELLOW}➜${RESET}  Open a ${BOLD}new Kitty terminal${RESET} to see your rice! 🎀"
    echo -e "  ${YELLOW}➜${RESET}  Run: ${CYAN}python3 $LOCAL_BIN/neko-greeting${RESET}"
    echo -e "  ${YELLOW}➜${RESET}  Skip: ${CYAN}WAIFU_SKIP=1 zsh${RESET}"
    echo
    echo -e "  ${DIM}Flags:${RESET}"
    echo -e "  ${DIM}  --no-kitty    skip Kitty installation${RESET}"
    echo -e "  ${DIM}  --no-waifu    skip waifu greeting${RESET}"
    echo -e "  ${DIM}  --no-zsh      skip zsh/omz/starship/.zshrc${RESET}"
    echo -e "  ${DIM}  --unattended  non-interactive mode${RESET}"
    echo -e "  ${DIM}  --help        this message${RESET}"
    echo
    # Remind user about chsh if still needed
    if [ "$SHELL" != "$(command -v zsh 2>/dev/null || true)" ]; then
        warn "shell not changed — run: chsh -s $(command -v zsh)"
    fi
}

# ── CLI Parser ──────────────────────────────────────────────────────────────
usage() {
    cat <<USAGE
Usage: ./${SCRIPT_NAME} [options]

Options:
  --no-kitty     Skip Kitty Terminal installation
  --no-waifu     Skip waifu greeting script
  --no-zsh       Skip zsh/Oh My Zsh/Starship/.zshrc
  --unattended   Non-interactive mode (fewer prompts)
  --help         Show this message

Defaults: installs everything, interactive mode.
USAGE
    exit 0
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-kitty)    DO_KITTY=false; shift ;;
            --no-waifu)    DO_WAIFU=false; shift ;;
            --no-zsh)      DO_ZSH=false; DO_STARSHIP=false; shift ;;
            --unattended)  UNATTENDED=true; shift ;;
            --help|-h)     usage ;;
            *)             warn "unknown option: $1"; shift ;;
        esac
    done
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    echo
    echo -e "${BOLD}${MAGENTA}  🌸  my-term setup  ${RESET}${DIM}v2.0${RESET}"
    echo -e "${DIM}  Kitty · Starship · Oh My Zsh · Waifu${RESET}"
    echo

    preflight
    setup_zsh
    setup_omz
    setup_font
    setup_starship
    setup_kitty
    setup_waifu
    setup_zshrc
    show_summary
}

main "$@"
