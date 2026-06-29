#!/usr/bin/env python3
"""
🌸 Waifu Greeting — random anime PNG on every terminal launch.
Round-robin from a local cache (100 images). Refills in background.
"""
import os, sys, random, json, shutil, hashlib, time, base64, traceback, subprocess, threading
from pathlib import Path
from datetime import datetime
from urllib.request import urlopen, Request

CACHE_DIR = os.path.expanduser("~/.cache/waifu-greeting")
CACHE_TARGET = 100
REFILL_THRESHOLD = 20
API_URL = "https://nekos.best/api/v2/{endpoint}"
ENDPOINTS = ["waifu", "neko", "smile", "kitsune", "hug", "pat", "cuddle"]
UA = "waifu-greeting/1.0"
LOCK = Path(CACHE_DIR) / ".refill_lock"
INDEX_FILE = Path(CACHE_DIR) / ".index"

def fetch_image_url():
    ep = random.choice(ENDPOINTS)
    try:
        req = Request(API_URL.format(endpoint=ep),
                      headers={"User-Agent": UA, "Accept": "application/json"})
        with urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())["results"][0]["url"]
    except Exception:
        return None

def download(url, dest):
    try:
        req = Request(url, headers={"User-Agent": UA})
        with urlopen(req, timeout=20) as resp:
            with open(dest, "wb") as f:
                f.write(resp.read())
        return True
    except Exception:
        return False

def get_cached():
    p = Path(CACHE_DIR)
    if not p.exists():
        return []
    return sorted(
        [f for f in p.iterdir()
         if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".gif") and f.is_file()],
        key=lambda x: x.name
    )

def refill():
    """Download images with 5 threads for speed."""
    Path(CACHE_DIR).mkdir(parents=True, exist_ok=True)
    lock = LOCK
    lock.write_text(str(os.getpid()))
    try:
        seen = {f.name for f in get_cached()}
        def worker():
            while len([f for f in Path(CACHE_DIR).iterdir()
                      if f.suffix.lower() in (".png",".jpg",".jpeg")]) < CACHE_TARGET:
                url = fetch_image_url()
                if not url:
                    continue
                name = hashlib.md5(url.encode()).hexdigest() + ".png"
                if name in seen:
                    continue
                if download(url, str(Path(CACHE_DIR) / name)):
                    seen.add(name)
        threads = [threading.Thread(target=worker, daemon=True) for _ in range(5)]
        for t in threads: t.start()
        for t in threads: t.join()
    finally:
        lock.unlink(missing_ok=True)

def in_kitty():
    return ("kitty" in os.environ.get("TERM", "").lower()
            or os.environ.get("KITTY_WINDOW_ID")
            or os.environ.get("KITTY_PID"))

def display_image(path):
    """Display image after the greeting, then advance cursor past it."""
    try:
        if not in_kitty():
            return False
        kitten = shutil.which("kitten") or os.path.expanduser("~/.local/kitty/bin/kitten")
        if not os.path.exists(kitten):
            return False

        cols, lines = shutil.get_terminal_size()
        cell_w, cell_h = 9, 20

        # Pre-resize to max 35% terminal height
        from PIL import Image as PILImage
        with PILImage.open(path) as img:
            img_w, img_h = img.size
        max_w = cols * cell_w
        max_h = int(lines * 0.35 * cell_h)
        scale = min(max_w / img_w, max_h / img_h, 1.0)

        temp = None
        if scale < 1.0:
            import tempfile
            nw, nh = int(img_w * scale), int(img_h * scale)
            temp = Path(tempfile.mktemp(suffix=".png"))
            with PILImage.open(path) as img:
                img.resize((nw, nh), PILImage.LANCZOS).save(temp)
            pcol = max(10, min(cols, int(nw / cell_w)))
            prow = max(4, min(int(lines * 0.35), int(nh / cell_h)))
            display_path = temp
        else:
            pcol = max(10, min(cols, int(img_w / cell_w)))
            prow = max(4, min(int(lines * 0.35), int(img_h / cell_h)))
            display_path = path

        # All three are required for icat to work without TTY access:
        # --use-window-size, --place, --transfer-mode
        px_w = cols * cell_w
        px_h = lines * cell_h

        proc = subprocess.Popen(
            [kitten, "icat",
             "--transfer-mode=file", "--stdin=no",
             "--use-window-size", f"{cols},{lines},{px_w},{px_h}",
             "--place", f"{pcol}x{prow}@0x3",
             "--align", "center",
             str(display_path)],
            stdin=subprocess.DEVNULL,
            stdout=sys.stdout, stderr=sys.stderr,
            start_new_session=True,
        )
        proc.wait()
        if temp and temp.exists():
            temp.unlink(missing_ok=True)

        # Advance cursor past the image area
        print(f"\033[{prow + 1}B", end="")
        sys.stdout.flush()
        return True
    except Exception:
        return False

def greeting():
    h = datetime.now().hour
    if h < 12:
        return random.choice(["✨ Ohayou! ✨", "🌅 Good morning! ✨", "☀️ Ohayou gozaimasu! ✨"])
    elif h < 17:
        return random.choice(["✨ Konnichiwa! ✨", "🌞 Hello! ✨", "🌸 Konnichiwa! ✨"])
    elif h < 22:
        return random.choice(["✨ Konbanwa! ✨", "🌆 Good evening! ✨", "🌙 Konbanwa! ✨"])
    else:
        return random.choice(["✨ Oyasumi... ✨", "🌙 Late night? ✨", "💤 Oyasuminasai... ✨"])

def errlog(msg):
    print(f"[neko-greeting] {msg}", file=sys.stderr)

def main():
    try:
        if os.environ.get("NEKO_SKIP") or os.environ.get("WAIFU_SKIP"):
            return
        if "--refill" in sys.argv:
            refill()
            return

        # ── 1. Greeting text at the top ──
        msg = greeting()
        w = shutil.get_terminal_size().columns
        print(f"\n{msg:^{w}}\n")

        # ── 2. Image at cursor position; icat auto-advances cursor ──
        images = get_cached()
        if not images:
            errlog("cache empty — spawning refill")
            subprocess.Popen([sys.executable, __file__, "--refill"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
        else:
            idx = int((INDEX_FILE.read_text().strip() or "0") if INDEX_FILE.exists() else "0")
            img = images[idx % len(images)]
            if not img.exists():
                errlog(f"image not found: {img}")
            elif not display_image(img):
                errlog(f"display_image failed for {img.name}")
            INDEX_FILE.write_text(str(idx + 1))

            if len(images) <= REFILL_THRESHOLD and not LOCK.exists():
                errlog("cache low — refilling in background")
                subprocess.Popen([sys.executable, __file__, "--refill"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True)
    except Exception as e:
        errlog(f"crash: {e}")
        traceback.print_exc(file=sys.stderr)

if __name__ == "__main__":
    main()
