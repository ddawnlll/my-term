from __future__ import annotations

from textual.app import App
from textual.binding import Binding

from .installer.kitty import KittyInstaller
from .installer.zsh import ZshInstaller
from .installer.starship import StarshipInstaller
from .installer.waifu import WaifuInstaller

from .screens.welcome import WelcomeScreen
from .screens.components import ComponentsScreen
from .screens.install import InstallScreen
from .screens.done import DoneScreen


MY_TERM_CSS = """
Screen {
    background: #1e1e2e;
}

Static, Label {
    color: #cdd6f4;
}

#banner {
    padding: 1 0;
    text-style: bold;
    color: #cba6f7;
}

#desc {
    padding: 1 4;
    text-align: center;
    color: #a6adc8;
}

#welcome-layout {
    align: center middle;
    padding: 2 4;
}

#comp-header {
    padding: 1 2;
    text-style: bold;
    color: #cba6f7;
}

#comp-list {
    margin: 0 2;
    height: 10;
}

#comp-buttons, #done-buttons {
    align: center middle;
    margin: 1 0;
}

#install-header {
    padding: 1 2;
    text-style: bold;
    color: #cba6f7;
}

#current-task {
    padding: 0 2;
    color: #89b4fa;
}

#install-log {
    margin: 0 2;
    height: 1fr;
}

#main-progress {
    margin: 0 2;
}

#done-title {
    padding: 1 0;
    text-style: bold;
    color: #a6e3a1;
}

#done-results {
    margin: 1 4;
    padding: 1 2;
    border: solid #45475a;
    height: 6;
}

#done-tips {
    padding: 1 2;
    text-align: center;
    color: #a6adc8;
}

Button {
    margin: 0 1;
}

Button.-primary-style {
    background: #89b4fa;
    color: #1e1e2e;
}

Button.-error-style {
    background: #f38ba8;
    color: #1e1e2e;
}

Button:hover {
    text-style: bold;
}

ListView {
    border: solid #45475a;
}

ListView > .list-view--item {
    padding: 0 1;
    color: #cdd6f4;
}

ListView > .list-view--item:hover {
    background: #313244;
}

ListView > .list-view--item:focus {
    background: #45475a;
}
"""


class MyTermApp(App):
    """my-term TUI setup application."""

    TITLE = "🌸 my-term setup"
    CSS = MY_TERM_CSS
    SCREENS = {
        "welcome": WelcomeScreen,
    }
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("escape", "pop_screen", "Back"),
    ]

    def __init__(self):
        super().__init__()
        self.installers = [
            KittyInstaller(),
            ZshInstaller(),
            StarshipInstaller(),
            WaifuInstaller(),
        ]

    def on_mount(self) -> None:
        self.push_screen("welcome")

    def get_screen(self, screen_name: str) -> WelcomeScreen | ComponentsScreen | InstallScreen | DoneScreen:
        if screen_name == "components":
            return ComponentsScreen(installers=self.installers)
        elif screen_name == "install":
            return InstallScreen()
        elif screen_name == "done":
            return DoneScreen()
        return super().get_screen(screen_name)

    def push_screen(self, screen_name: str, data=None) -> None:
        if screen_name == "components":
            screen = ComponentsScreen(installers=self.installers)
        elif screen_name == "install":
            screen = InstallScreen(installers=data or self.installers)
        elif screen_name == "done":
            screen = DoneScreen(results=data or [])
        else:
            screen = self.get_screen(screen_name)
        super().push_screen(screen)
