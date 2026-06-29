from __future__ import annotations

import shutil
from .base import BaseInstaller


class WaifuInstaller(BaseInstaller):
    name = "Waifu Greeting"
    description = "Anime girl PNG on terminal launch"
    icon = "🌸"

    def check(self) -> bool:
        return (self.local_bin / "neko-greeting").exists()

    async def install(self, progress_callback=None) -> bool:
        target = self.local_bin / "neko-greeting"

        if target.exists():
            self.log.append("Greeting already installed")
            return True

        self.local_bin.mkdir(parents=True, exist_ok=True)

        # Copy from repo
        repo_file = self.repo_dir / "neko-greeting.py"
        if repo_file.exists():
            shutil.copy2(repo_file, target)
            target.chmod(0o755)
            self.log.append("Copied from repo")
            if progress_callback:
                await progress_callback("✅ Greeting installed")
            return True

        # Download fallback
        if progress_callback:
            await progress_callback("Downloading greeting script…")
        import urllib.request
        url = "https://raw.githubusercontent.com/yukaraca/my-term/main/neko-greeting.py"
        urllib.request.urlretrieve(url, str(target))
        target.chmod(0o755)
        self.log.append("Downloaded greeting script")

        if progress_callback:
            await progress_callback("✅ Greeting installed")
        return target.exists()
