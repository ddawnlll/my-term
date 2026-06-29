from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Center, Vertical
from textual.screen import Screen
from textual.widgets import Button, Label, Static


BANNER = """
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                          ┃
┃       🌸  my-term setup  v2.0  🌸        ┃
┃                                          ┃
┃    Kitty  ·  Oh My Zsh  ·  Starship      ┃
┃         Waifu Greeting                   ┃
┃                                          ┃
┃    Catppuccin Cozy Anime Rice         🎀  ┃
┃                                          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
"""


class WelcomeScreen(Screen):
    """Welcome / splash screen."""

    TITLE = "🌸 my-term"

    def compose(self) -> ComposeResult:
        yield Vertical(
            Center(Static(BANNER, id="banner")),
            Center(
                Label(
                    "This setup will transform your terminal with:\n"
                    "  😺  Kitty terminal — Catppuccin Mocha themed\n"
                    "  🐚  Zsh + Oh My Zsh with plugins\n"
                    "  🚀  Starship prompt\n"
                    "  🌸  Anime waifu greeting on launch",
                    id="desc",
                )
            ),
            Center(
                Button("▶  Start Setup", variant="primary", id="start-btn"),
                Button("✕  Quit", variant="error", id="quit-btn"),
            ),
            id="welcome-layout",
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "start-btn":
            self.app.push_screen("components")
        elif event.button.id == "quit-btn":
            self.app.exit()
