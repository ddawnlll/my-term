from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import Button, Label, ListItem, ListView, RichLog


class ComponentItem(ListItem):
    """A selectable component in the list."""

    def __init__(self, installer, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.installer = installer
        self.checked = True

    def compose(self):
        status = "✅" if self.checked else "⬜"
        yield Label(
            f"{status}  {self.installer.icon}  {self.installer.name}",
            id=f"comp-{self.installer.__class__.__name__}",
        )


class ComponentsScreen(Screen):
    """Component selection screen."""

    TITLE = "Choose Components"

    def __init__(self, installers=None, **kwargs):
        super().__init__(**kwargs)
        self.installers = installers or []

    def compose(self) -> ComposeResult:
        yield Vertical(
            Label("Select components to install:", id="comp-header"),
            ListView(*[ComponentItem(inst) for inst in self.installers], id="comp-list"),
            Horizontal(
                Button("▶  Install Selected", variant="primary", id="install-btn"),
                Button("◀  Back", variant="default", id="back-btn"),
                id="comp-buttons",
            ),
            RichLog(id="comp-status", highlight=True, markup=True),
        )

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Toggle selection when clicked."""
        item = event.item
        if isinstance(item, ComponentItem):
            item.checked = not item.checked
            status = "✅" if item.checked else "⬜"
            label = self.query_one(f"#comp-{item.installer.__class__.__name__}")
            if label:
                label.update(f"{status}  {item.installer.icon}  {item.installer.name}")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "install-btn":
            selected = [
                item.installer
                for item in self.query(ComponentItem)
                if item.checked
            ]
            if not selected:
                self.query_one("#comp-status", RichLog).write("[yellow]⚠ Select at least one component[/]")
                return
            self.app.push_screen("install", selected)
        elif event.button.id == "back-btn":
            self.app.pop_screen()
