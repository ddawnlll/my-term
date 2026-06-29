from __future__ import annotations

import asyncio
from textual.app import ComposeResult
from textual.containers import Vertical
from textual.screen import Screen
from textual.widgets import Button, Header, Label, ProgressBar, RichLog


class InstallScreen(Screen):
    """Installation progress screen."""

    TITLE = "Installing"

    def __init__(self, installers=None, **kwargs):
        super().__init__(**kwargs)
        self.installers = installers or []
        self.results = []

    def compose(self) -> ComposeResult:
        yield Vertical(
            Label("Installing components…", id="install-header"),
            ProgressBar(total=len(self.installers), show_eta=True, id="main-progress"),
            Label("", id="current-task"),
            RichLog(id="install-log", highlight=True, markup=True, max_lines=100),
        )

    def on_mount(self) -> None:
        self.run_install()

    async def progress_callback(self, msg):
        """Called by installers to update current task."""
        self.query_one("#current-task", Label).update(f"  {msg}")
        self.log_message(f"[dim]{msg}[/]")

    def log_message(self, msg):
        self.query_one("#install-log", RichLog).write(msg)

    async def run_install(self):
        progress = self.query_one("#main-progress", ProgressBar)

        for i, installer in enumerate(self.installers):
            try:
                self.query_one("#current-task", Label).update(
                    f"  {installer.icon}  {installer.name}…"
                )
                self.log_message(f"\n[bold]{installer.icon}  {installer.name}[/]")

                success = await installer.install(
                    progress_callback=self.progress_callback
                )

                if success:
                    self.log_message(f"[green]✔  {installer.name} done[/]")
                else:
                    self.log_message(f"[red]✘  {installer.name} failed[/]")

            except Exception as exc:
                self.log_message(f"[red]✘  {installer.name} error: {exc}[/]")
                success = False

            self.results.append((installer, success))
            progress.advance(1)
            await asyncio.sleep(0.1)

        self.app.push_screen("done", self.results)
