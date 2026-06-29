from __future__ import annotations

import shutil
import time
from pathlib import Path
from .base import BaseInstaller


class ZshInstaller(BaseInstaller):
    name = "Zsh + Oh My Zsh"
    description = "Shell framework, plugins, and .zshrc"
    icon = "🐚"

    def check(self) -> bool:
        return (self.home / ".zshrc").exists() and (self.home / ".oh-my-zsh").exists()

    async def install(self, progress_callback=None) -> bool:
        if progress_callback:
            await progress_callback("Checking zsh…")

        # zsh
        if not shutil.which("zsh"):
            await self.run_cmd_sudo(["pacman", "-S", "--noconfirm", "zsh"])
        else:
            self.log.append("zsh already installed")

        # Oh My Zsh
        omz_dir = self.home / ".oh-my-zsh"
        if not omz_dir.exists():
            if progress_callback:
                await progress_callback("Installing Oh My Zsh…")
            import urllib.request
            url = "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
            urllib.request.urlretrieve(url, "/tmp/omz-install.sh")
            await self.run_cmd(["sh", "/tmp/omz-install.sh", "", "--unattended"])
        else:
            self.log.append("Oh My Zsh already installed")

        # Plugins
        custom = f"{self.home}/.oh-my-zsh/custom"
        plugins = {
            "zsh-autosuggestions": "https://github.com/zsh-users/zsh-autosuggestions",
            "zsh-syntax-highlighting": "https://github.com/zsh-users/zsh-syntax-highlighting",
        }
        for name, url in plugins.items():
            target = Path(f"{custom}/plugins/{name}")
            if not target.exists():
                if progress_callback:
                    await progress_callback(f"Installing plugin: {name}…")
                await self.run_cmd(["git", "clone", "--depth", "1", "--quiet", url, str(target)])
            else:
                self.log.append(f"Plugin {name} already installed")

        # .zshrc
        zshrc_src = self.repo_dir / "configs" / "zsh" / ".zshrc"
        zshrc_dst = self.home / ".zshrc"
        if zshrc_src.exists():
            if zshrc_dst.exists():
                backup = zshrc_dst.with_suffix(f".bak.{int(time.time())}")
                zshrc_dst.rename(backup)
                self.log.append(f"Backed up existing .zshrc → {backup.name}")
            shutil.copy2(zshrc_src, zshrc_dst)
            self.log.append(".zshrc written")
            if progress_callback:
                await progress_callback("✅ .zshrc deployed")
        return True
