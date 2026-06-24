# 🌸 my-term

> **Kitty + Starship + Oh My Zsh + Anime Waifu Greeting**

A terminal setup that shows a **random anime girl PNG** every time you open Kitty.

## 📦 What's Included

| Component | Description |
|-----------|-------------|
| [`setup.sh`](setup.sh) | One-command installer — Kitty, Oh My Zsh, Starship, fonts, greeting |
| [`neko-greeting.py`](neko-greeting.py) | Displays a cached anime PNG via Kitty graphics protocol |

## 🚀 Quick Start

```bash
# 1. Clone and run
git clone https://github.com/yukaraca/my-term.git ~/src/my-term
cd ~/src/my-term
./setup.sh

# 2. Open a new Kitty terminal → 🖼️
```

## 🖼️ How the Greeting Works

- Each terminal launch shows the **next cached anime girl** (round-robin)
- **100 images** cached locally — instant display, no internet needed
- When cache runs low, **background refill** with 5 threads
- Uses **nekos.best API** — high-quality SFW anime art
- Display via **Kitty graphics protocol** (`kitten icat` with `--use-window-size`)

### Skip greeting

```zsh
WAIFU_SKIP=1 zsh    # or NEKO_SKIP=1 (old)
```

## 🔧 Manual Setup Steps

1. Install **Kitty** terminal
2. Install **Oh My Zsh** + plugins (autosuggestions, syntax-highlighting)
3. Install **Starship** prompt
4. Drop `neko-greeting.py` to `~/.local/bin/neko-greeting`
5. Add to `.zshrc`:
   ```zsh
   if [[ -z "${WAIFU_SKIP:-}" && -z "${SSH_CONNECTION:-}" && -t 0 ]]; then
     neko-greeting
   fi
   ```

## 📸 Preview

*(coming soon)*

## 📄 License

MIT
