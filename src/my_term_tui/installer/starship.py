from __future__ import annotations

import shutil
from .base import BaseInstaller


class StarshipInstaller(BaseInstaller):
    name = "Starship Prompt"
    description = "Fast shell prompt"
    icon = "🚀"

    def check(self) -> bool:
        return bool(shutil.which("starship"))

    async def install(self, progress_callback=None) -> bool:
        starship_bin = self.local_bin / "starship"
        if starship_bin.exists():
            self.log.append("Starship already installed")
            return True

        if progress_callback:
            await progress_callback("Downloading Starship…")

        import urllib.request
        url = "https://starship.rs/install.sh"
        urllib.request.urlretrieve(url, "/tmp/starship-install.sh")
        code, out, err = await self.run_cmd(
            ["sh", "/tmp/starship-install.sh", "-y", "-b", str(self.local_bin)]
        )
        if code == 0:
            if progress_callback:
                await progress_callback("✅ Starship installed")
            return True

        # Fallback: manual download
        if progress_callback:
            await progress_callback("Trying manual download…")
        import platform
        arch_map = {"x86_64": "x86_64-unknown-linux-musl", "aarch64": "aarch64-unknown-linux-musl"}
        arch = arch_map.get(platform.machine(), "x86_64-unknown-linux-musl")
        url = f"https://github.com/starship/starship/releases/latest/download/starship-{arch}.tar.gz"
        await self.run_cmd(["curl", "-sSL", url, "-o", "/tmp/starship.tar.gz"])
        await self.run_cmd(["tar", "-xzf", "/tmp/starship.tar.gz", "-C", str(self.local_bin), "starship"])
        await self.run_cmd(["chmod", "+x", str(starship_bin)])
        status = starship_bin.exists()
        if progress_callback:
            await progress_callback("✅ Starship installed" if status else "❌ Starship failed")
        return status
