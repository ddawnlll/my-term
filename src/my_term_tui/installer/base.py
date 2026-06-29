from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any, Callable


class InstallerError(Exception):
    pass


ProgressCB = Callable[[str], None] | Callable[[str], Any] | None


class BaseInstaller:
    """Base class for component installers."""

    name: str = ""
    description: str = ""
    icon: str = ""
    repo_dir: Path = Path(__file__).resolve().parent.parent.parent.parent

    def __init__(self) -> None:
        self.log: list[str] = []

    def check(self) -> bool:
        """Return True if component is already installed."""
        raise NotImplementedError

    async def install(self, progress_callback: ProgressCB = None) -> bool:
        """Install the component. Return True on success."""
        raise NotImplementedError

    async def run_cmd(
        self,
        cmd: list[str],
        **kwargs: Any,
    ) -> tuple[int, str, str]:
        """Run a command asynchronously so the Textual event loop stays responsive.

        Returns (returncode, stdout, stderr).
        Never raises — errors are captured in the return tuple.
        """
        self.log.append(f"$ {' '.join(cmd)}")

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                **kwargs,
            )
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=120
            )
        except asyncio.TimeoutError:
            self.log.append("⏱  timed out after 120s")
            return (-1, "", "timeout")
        except FileNotFoundError:
            self.log.append(f"✘  command not found: {cmd[0]}")
            return (-1, "", f"command not found: {cmd[0]}")
        except Exception as exc:
            self.log.append(f"✘  {exc}")
            return (-2, "", str(exc))

        out = stdout.decode("utf-8", errors="replace").strip() if stdout else ""
        err = stderr.decode("utf-8", errors="replace").strip() if stderr else ""

        if out:
            for line in out.split("\n"):
                self.log.append(f"  {line}")
        if err:
            for line in err.split("\n"):
                self.log.append(f"  ! {line}")

        return (proc.returncode or 0, out, err)

    async def run_cmd_sudo(
        self,
        cmd: list[str],
        progress_callback: ProgressCB = None,
    ) -> tuple[int, str, str]:
        """Run a command with sudo, handling password prompts gracefully.

        Uses sudo -n (non-interactive) first; if that fails, tries with
        a cached credential prompt via sudo -v.
        """
        sudo_cmd = ["sudo"] + cmd

        # First try non-interactive
        code, out, err = await self.run_cmd(sudo_cmd, env={**__import__("os").environ, "SUDO_ASKPASS": ""})
        if code == 0:
            return (code, out, err)

        # If that fails, try with sudo -A (askpass) or just return the error
        if "password" in err.lower() or "try again" in err.lower():
            if progress_callback:
                await progress_callback("⚠️  sudo password required — please enter it")
            code, out, err = await self.run_cmd(
                ["sudo", "-S"] + cmd,
                stdin=asyncio.subprocess.PIPE,
            )
        return (code, out, err)

    @property
    def is_arch(self) -> bool:
        os_release = Path("/etc/os-release")
        if os_release.exists():
            content = os_release.read_text().lower()
            return "id=arch" in content or "id_like=arch" in content
        return False

    @property
    def home(self) -> Path:
        return Path.home()

    @property
    def local_bin(self) -> Path:
        return self.home / ".local" / "bin"
