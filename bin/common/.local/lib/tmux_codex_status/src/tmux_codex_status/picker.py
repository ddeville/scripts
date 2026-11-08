"""Browse live Codex conversations using Textual's navigation and layout."""

import asyncio
import os
import time
from contextlib import aclosing

from rich.text import Text
from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, VerticalScroll
from textual.events import Resize
from textual.widgets import OptionList, Static, Tab, Tabs
from textual.widgets.option_list import Option
from websockets.exceptions import WebSocketException

from tmux_codex_status import status, tmux, view
from tmux_codex_status.status import JsonObject

FILTERS = {
    "all": "All",
    "attention": "Needs you",
    "working": "Working",
    "ready": "Unread",
    "idle": "Idle",
}
JUMP_KEYS = "1234567890"
HINTS = "1–9/0 jump · j/k move · Enter open · q close"
DETAIL_HINTS = "Tab filter · Ctrl-f needs you · h/l details · e expand"


class Picker(App[list[str] | None]):
    """Coordinate status reads and a pair of standard scrolling widgets."""

    ENABLE_COMMAND_PALETTE = False
    CSS = """
    Screen { padding: 1 2 0 2; background: ansi_default; color: ansi_default; }
    #heading { height: 1; }
    #summary { height: auto; min-height: 1; }
    Tabs { height: 2; }
    Tabs Underline { display: none; }
    Tab { color: ansi_bright_black; text-style: none; }
    Tab.-active { color: ansi_yellow; background: #3a3a3a; text-style: none; }
    Tab#attention.has-attention { color: ansi_red; }
    Horizontal { height: 1fr; }
    OptionList {
        width: 3fr; height: 1fr; padding: 0; border: none; scrollbar-size: 1 1;
        scrollbar-color: ansi_bright_black;
    }
    #details {
        width: 2fr; padding: 0 1; border-left: solid ansi_bright_black;
        scrollbar-size: 0 0;
    }
    OptionList, #details { border-top: solid ansi_bright_black; border-title-color: ansi_bright_black; }
    OptionList:focus, #details:focus { border-title-color: ansi_yellow; background-tint: transparent; }
    OptionList > .option-list--option-highlighted,
    OptionList:focus > .option-list--option-highlighted {
        background: #3a3a3a; color: ansi_default; text-style: none;
    }
    OptionList > .option-list--option-disabled { color: ansi_bright_black; text-style: none; }
    OptionList > .option-list--option-hover { background: transparent; }
    #footer { height: 3; border-top: solid ansi_bright_black; color: ansi_bright_black; }
    .narrow #details { display: none; }
    .narrow.details-focus #tasks, .expanded #tasks { display: none; }
    .narrow.details-focus #details, .expanded #details { display: block; border-left: none; }
    """
    BINDINGS = [
        Binding("escape,q,ctrl+c", "quit", show=False, priority=True),
        Binding("tab", "cycle_filter(1)", show=False, priority=True),
        Binding("shift+tab", "cycle_filter(-1)", show=False, priority=True),
        Binding("ctrl+f", "attention", show=False),
        Binding("h,left", "focus_pane('tasks')", show=False, priority=True),
        Binding("l,right", "focus_pane('details')", show=False, priority=True),
        Binding("j", "navigate('down')", show=False),
        Binding("k", "navigate('up')", show=False),
        Binding("ctrl+d", "navigate('down', True)", show=False),
        Binding("ctrl+u", "navigate('up', True)", show=False),
        Binding("e", "expand", show=False),
        Binding("enter", "open_thread", show=False, priority=True),
        *[Binding(key, f"open_shortcut('{key}')", show=False, priority=True) for key in JUMP_KEYS],
    ]

    def __init__(self, client: str) -> None:
        """Create the widgets and the small amount of application state."""
        super().__init__(ansi_color=True)
        self.theme = "ansi-dark"
        self.animation_level = "none"
        self.tmux_client = client
        self.agents: list[JsonObject] = []
        self.positions: dict[str, int] = {}
        self.loaded_thread_ids: list[str] = []
        self.selected_id: str | None = None
        self.details_data: JsonObject = {}
        self.received_at = 0.0
        self.error = "Connecting to Codex…"
        self.notice = ""
        self.expanded = False
        self.heading = Static(Text("Codex agents", "yellow"), id="heading")
        self.summary = Static(Text("Connecting to Codex…", "bright_black"), id="summary")
        self.tabs = Tabs(*(Tab(label, id=key) for key, label in FILTERS.items()), active="all")
        self.tasks = OptionList(id="tasks")
        self.details = Static()
        self.details_scroll = VerticalScroll(self.details, id="details")
        self.footer = Static(id="footer")

    def compose(self) -> ComposeResult:
        """Let Textual lay out the header, list, details, and footer."""
        yield self.heading
        yield self.summary
        yield self.tabs
        with Horizontal():
            yield self.tasks
            yield self.details_scroll
        yield self.footer

    def on_mount(self) -> None:
        """Start polling and focus the task list."""
        self.tasks.border_title = "Agents · press a number to open"
        self.details_scroll.border_title = "Selected agent"
        self.tasks.focus()
        self.poll_status()
        self.set_interval(1, self.update_footer)

    def filtered(self, key: str) -> list[JsonObject]:
        """Select the conversations belonging to a status tab."""
        if key == "all":
            return self.agents
        if key == "attention":
            return [agent for agent in self.agents if agent["needs_attention"]]
        return [agent for agent in self.agents if agent["status"] == key]

    def update_agents(self, agents: list[JsonObject]) -> None:
        """Prioritize new agents while keeping existing rows and jump keys stable."""
        self.loaded_thread_ids = [agent["id"] for agent in agents]
        self.agents = sorted(
            (agent for agent in agents if agent["tmux_panes"]),
            key=lambda agent: (
                self.positions.get(agent["id"], len(self.positions)),
                status.STATES.index(agent["status"]),
                agent["cwd"].casefold(),
                agent["title"].casefold(),
                agent["id"],
            ),
        )
        for agent in self.agents:
            self.positions.setdefault(agent["id"], len(self.positions))

    @work
    async def poll_status(self) -> None:
        """Read status until Textual cancels the worker on exit."""
        async with aclosing(status.CodexClient()) as client:
            while True:
                data = await status.snapshot(client)
                self.error = data["connection"]["error"] or ""
                if not self.error:
                    self.received_at = time.monotonic()
                    self.update_agents(data["agents"])
                    self.summary.update(view.attention_summary(self.agents))
                    stamp = time.strftime(
                        "%I:%M:%S %p", time.localtime(data["generated_at"])
                    ).lstrip("0")
                    self.heading.update(
                        Text.assemble(
                            ("Codex agents", "yellow"),
                            (f"  tmux · updated {stamp}", "bright_black"),
                        )
                    )
                    for key, label in FILTERS.items():
                        tab = self.tabs.query_one(f"#{key}", Tab)
                        tab.label = f"{label} {len(self.filtered(key))}"
                    self.tabs.query_one("#attention", Tab).set_class(
                        bool(self.filtered("attention")), "has-attention"
                    )
                self.update_list()
                self.update_footer()
                await asyncio.sleep(2)

    def update_list(self) -> None:
        """Refresh rows without resetting selection or scrolling."""
        agents = self.filtered(self.tabs.active)
        options = view.task_options(agents, self.positions) or [
            Option(
                Text(self.error or "No conversations match this filter", "bright_black"),
                disabled=True,
            )
        ]
        visible_ids = [agent["id"] for agent in agents]
        selected_id = self.selected_id
        if selected_id not in visible_ids:
            selected_id = visible_ids[0] if visible_ids else None
        with self.prevent(OptionList.OptionHighlighted):
            if [option.id for option in options] == [option.id for option in self.tasks.options]:
                for index, option in enumerate(options):
                    self.tasks.replace_option_prompt_at_index(index, option.prompt)
            else:
                self.tasks.set_options(options)
            self.tasks.highlighted = (
                self.tasks.get_option_index(selected_id) if selected_id else None
            )
        self.select_thread(selected_id)

    def on_tabs_tab_activated(self, event: Tabs.TabActivated) -> None:
        """Apply the selected status filter."""
        self.update_list()

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        """Load details for the highlighted conversation."""
        self.select_thread(event.option_id)

    def select_thread(self, thread_id: str | None) -> None:
        """Keep details fresh while preserving scroll on ordinary status updates."""
        if thread_id != self.selected_id:
            self.selected_id = thread_id
            self.notice = ""
            self.details_data = {}
            self.details_scroll.scroll_home(animate=False)
            self.workers.cancel_group(self, "details")
            if thread_id:
                self.poll_details(thread_id)
        self.show_details()

    @work(group="details", exclusive=True)
    async def poll_details(self, thread_id: str) -> None:
        """Poll the selected thread; changing selection cancels this worker."""
        async with aclosing(status.CodexClient()) as client:
            while True:
                try:
                    self.details_data = await status.detail(client, thread_id)
                except (OSError, ValueError, WebSocketException, status.RpcError) as exc:
                    await client.aclose()
                    self.details_data = {"history_error": str(exc) or type(exc).__name__}
                self.show_details()
                await asyncio.sleep(2)

    def show_details(self) -> None:
        """Render history with the most recent status metadata."""
        agent = next((agent for agent in self.agents if agent["id"] == self.selected_id), None)
        self.details.update(view.detail_text(agent, self.details_data))

    def update_footer(self) -> None:
        """Show connection errors and stale data alongside normal keyboard hints."""
        message = self.notice or self.error
        if not message and time.monotonic() - self.received_at > 10:
            message = "Status is stale; waiting for Codex"
        footer = Text(HINTS + "\n", "bright_black")
        footer.append(message or DETAIL_HINTS, "magenta" if message else "bright_black")
        self.footer.update(footer)

    def on_resize(self, event: Resize) -> None:
        """Show one pane at a time on narrow terminals."""
        self.screen.set_class(event.size.width < 96, "narrow")

    def on_descendant_focus(self) -> None:
        """Keep the focused pane visible after mouse or keyboard navigation."""
        self.screen.set_class(self.details_scroll.has_focus, "details-focus")

    def action_cycle_filter(self, direction: int) -> None:
        """Cycle status tabs without changing keyboard focus."""
        keys = list(FILTERS)
        self.tabs.active = keys[(keys.index(self.tabs.active) + direction) % len(keys)]

    def action_attention(self) -> None:
        """Toggle between all conversations and those needing attention."""
        self.tabs.active = "all" if self.tabs.active == "attention" else "attention"

    def action_focus_pane(self, pane: str) -> None:
        """Focus the list or its details."""
        if pane == "tasks":
            self.expanded = False
        self.screen.set_class(self.expanded, "expanded")
        self.screen.set_class(pane == "details", "details-focus")
        self.set_focus(self.tasks if pane == "tasks" else self.details_scroll)

    async def action_navigate(self, direction: str, half_page: bool = False) -> None:
        """Reuse widget navigation actions for Vim keys."""
        widget = self.tasks if self.focused is self.tasks else self.details_scroll
        amount = max(1, widget.size.height // 2) if half_page else 1
        if widget is self.tasks:
            for _ in range(amount):
                await widget.run_action(f"cursor_{direction}")
        else:
            widget.scroll_relative(
                y=amount if direction == "down" else -amount, animate=False, immediate=True
            )

    def action_expand(self) -> None:
        """Expand or restore the details pane."""
        self.expanded = not self.expanded
        self.action_focus_pane("details" if self.expanded else "tasks")

    def finish(self, command: list[str] | None = None) -> None:
        """Let tmux restore the popup immediately, or clean up a standalone terminal."""
        if self.tmux_client:
            command = command or ["tmux", "display-popup", "-C", "-c", self.tmux_client]
            os.execvp(command[0], command)
        self.exit(command)

    async def action_quit(self) -> None:
        """Close the picker without waiting for input polling inside a popup."""
        self.finish()

    def action_open_shortcut(self, key: str) -> None:
        """Open a numbered agent without changing numbers when filtering."""
        position = JUMP_KEYS.index(key)
        for agent in self.filtered(self.tabs.active):
            if self.positions[agent["id"]] == position:
                self.action_open_thread(agent["id"])
                return

    @work(group="open", exclusive=True)
    async def action_open_thread(self, thread_id: str | None = None) -> None:
        """Verify the selected pane before leaving the popup."""
        thread_id = thread_id or self.selected_id
        if not thread_id:
            return
        if self.error or time.monotonic() - self.received_at > 10:
            self.notice = "Status unavailable; wait for a fresh update"
            self.update_footer()
            return
        try:
            command = await asyncio.to_thread(
                tmux.switch_command, thread_id, self.loaded_thread_ids, self.tmux_client
            )
        except (OSError, ValueError) as exc:
            self.notice = view.clean(exc)
            self.update_footer()
        else:
            self.finish(command)


def run(client: str) -> None:
    """Run the picker, then switch the invoking tmux client."""
    if command := Picker(client).run():
        os.execvp(command[0], command)
