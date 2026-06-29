from __future__ import annotations

import shutil
from pathlib import Path
from .base import BaseInstaller


class KittyInstaller(BaseInstaller):
    name = "Kitty Terminal"
    description = "GPU-accelerated terminal emulator with Catppuccin rice"
    icon = "😺"

    def check(self) -> bool:
        kitty_conf = self.home / ".config" / "kitty" / "kitty.conf"
        return kitty_conf.exists() and bool(shutil.which("kitty"))

    async def install(self, progress_callback=None) -> bool:
        if progress_callback:
            await progress_callback("Setting up Kitty…")

        # Install kitty via pacman on Arch if missing
        if not shutil.which("kitty"):
            if self.is_arch:
                if progress_callback:
                    await progress_callback("Installing kitty via pacman…")
                code, out, err = await self.run_cmd_sudo(
                    ["pacman", "-S", "--noconfirm", "kitty"],
                    progress_callback=progress_callback,
                )
                if code != 0:
                    self.log.append("Kitty install failed — install manually")
                    return False
            else:
                self.log.append("Kitty not found — install manually")
                return False

        # Deploy Catppuccin rice configs
        kitty_conf_dir = self.home / ".config" / "kitty"
        kitty_conf_dir.mkdir(parents=True, exist_ok=True)

        files = [
            ("catppuccin-mocha.conf", "catppuccin-mocha.conf"),
            ("kitty.conf", "kitty.conf"),
        ]
        for src_name, dst_name in files:
            src = self.repo_dir / "configs" / "kitty" / src_name
            if src.exists():
                dest = kitty_conf_dir / dst_name
                dest.write_text(src.read_text())
                self.log.append(f"Deployed {dst_name}")

        # Refresh desktop database
        if progress_callback:
            await progress_callback("Refreshing desktop database…")
        await self.run_cmd_sudo(["update-desktop-database"])
        await self.run_cmd_sudo(
            ["gtk-update-icon-cache", "-f", "/usr/share/icons/hicolor"]
        )

        if progress_callback:
            await progress_callback("✅ Kitty riced!")
        return True
