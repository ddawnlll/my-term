from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Center, Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import Button, Label, Static


class DoneScreen(Screen):
    """Completion / summary screen."""

    TITLE = "Done!"

    def __init__(self, results=None, **kwargs):
        super().__init__(**kwargs)
        self.results = results or []

    def compose(self) -> ComposeResult:
        yield Vertical(
            Center(Static("✨  Setup Complete!  ✨", id="done-title")),
            Vertical(id="done-results"),
            Center(
                Label(
                    "\n➜  Open a new Kitty terminal to see your rice!\n"
                    "➜  Run:  neko-greeting\n"
                    "➜  Skip:  WAIFU_SKIP=1 zsh",
                    id="done-tips",
                )
            ),
            Horizontal(
                Button("◀  Back", variant="default", id="back-btn"),
                Button("✕  Quit", variant="primary", id="quit-btn"),
                id="done-buttons",
            ),
        )

    def on_mount(self) -> None:
        results_box = self.query_one("#done-results")
        for installer, success in self.results:
            icon = "✅" if success else "❌"
            results_box.mount(
                Label(f"  {icon}  {installer.icon}  {installer.name}")
            )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back-btn":
            while len(self.app.screen_stack) > 1:
                self.app.pop_screen()
        elif event.button.id == "quit-btn":
            self.app.exit()
