"""Browse live Codex conversations in a tmux popup."""

import asyncio
import os
import time
from contextlib import closing
from queue import Empty, Queue
from threading import Event, Thread

from prompt_toolkit.application import Application
from prompt_toolkit.data_structures import Point
from prompt_toolkit.formatted_text import StyleAndTextTuples, fragment_list_width
from prompt_toolkit.key_binding import KeyBindings, KeyPressEvent
from prompt_toolkit.layout import Layout, Window
from prompt_toolkit.layout.controls import UIContent, UIControl
from prompt_toolkit.output import ColorDepth
from websockets.exceptions import WebSocketException

from tmux_codex_status import status, tmux, view
from tmux_codex_status.status import JsonObject

FILTERS = (
    ("All", "all"),
    ("Needs you", "attention"),
    ("Working", "working"),
    ("Ready", "ready"),
    ("Idle", "idle"),
)
STALE_AFTER = 10


class Picker(UIControl):
    """Keep selection, filters, and details independent of background reads."""

    def __init__(self, client: str) -> None:
        """Create the dashboard and its background work queues."""
        self.client = client
        self.agents: list[JsonObject] = []
        self.thread_ids: list[str] = []
        self.selected: str | None = None
        self.details: JsonObject = {}
        self.filter_index = 0
        self.details_focused = False
        self.expanded = False
        self.list_scroll = 0
        self.detail_scroll = 0
        self.body_height = 1
        self.detail_height = 0
        self.updated_at = 0.0
        self.received_at: float | None = None
        self.connection_error = "Connecting to Codex…"
        self.notice = ""
        self.opening = False
        self.stopped = Event()
        self.updates: Queue[tuple[str | None, JsonObject]] = Queue()
        self.detail_requests: Queue[str | None] = Queue()
        self.app: Application[list[str] | None] = Application(
            layout=Layout(Window(self)),
            key_bindings=self.bindings(),
            style=view.STYLE,
            color_depth=ColorDepth.DEPTH_8_BIT,
            full_screen=True,
            before_render=self.apply_updates,
            refresh_interval=1,
        )
        self.app.ttimeoutlen = 0.05
        self.app.timeoutlen = 0.05

    def is_focusable(self) -> bool:
        """Receive keyboard input without a text entry field."""
        return True

    def create_content(self, width: int, height: int) -> UIContent:
        """Build the visible screen, keeping scrolling inside each pane."""
        lines = self.screen(width, height)
        return UIContent(
            get_line=lambda index: lines[index],
            line_count=len(lines),
            cursor_position=Point(0, 0),
            show_cursor=False,
        )

    def filtered(self, filter_index: int | None = None) -> list[JsonObject]:
        """Return threads matching a tab, in project order."""
        key = FILTERS[self.filter_index if filter_index is None else filter_index][1]
        return [
            agent
            for agent in self.agents
            if key == "all"
            or (agent["needs_attention"] if key == "attention" else agent["status"] == key)
        ]

    def select(self, thread_id: str | None) -> None:
        """Select a thread and request its details without blocking input."""
        if thread_id != self.selected:
            self.selected = thread_id
            self.details = {}
            self.detail_scroll = 0
            self.notice = ""
        if thread_id is not None:
            self.detail_requests.put(thread_id)

    def reconcile_selection(self) -> None:
        """Keep the same thread selected whenever it remains visible."""
        ids = [agent["id"] for agent in self.filtered()]
        self.select(self.selected if self.selected in ids else next(iter(ids), None))

    def publish(self, thread_id: str | None, data: JsonObject) -> None:
        """Queue thread details, or a status snapshot when no thread ID is given."""
        if not self.stopped.is_set():
            self.updates.put((thread_id, data))
            self.app.invalidate()

    def collect_status(self) -> None:
        """Poll Codex and tmux using a connection owned by this worker."""
        with closing(status.CodexClient()) as client:
            while not self.stopped.is_set():
                self.publish(None, status.snapshot(client))
                self.stopped.wait(2)

    def collect_details(self) -> None:
        """Fetch only the newest requested selection on a separate connection."""
        with closing(status.CodexClient()) as client:
            while not self.stopped.is_set():
                thread_id = self.detail_requests.get()
                try:
                    while thread_id is not None:
                        thread_id = self.detail_requests.get_nowait()
                except Empty:
                    pass
                if thread_id is None:
                    return
                try:
                    data = status.detail(client, thread_id)
                except (OSError, ValueError, WebSocketException, status.RpcError) as exc:
                    client.close()
                    data = {"history_error": str(exc) or type(exc).__name__}
                self.publish(thread_id, data)

    def start(self) -> None:
        """Start daemon workers so slow server reads cannot delay closing the UI."""
        Thread(target=self.collect_status, daemon=True, name="codex-status").start()
        Thread(target=self.collect_details, daemon=True, name="codex-details").start()

    def stop(self) -> None:
        """Stop polling and wake the details worker for cleanup."""
        self.stopped.set()
        self.detail_requests.put(None)

    def apply_updates(self, app: Application[list[str] | None]) -> None:
        """Apply background results immediately before the next redraw."""
        while True:
            try:
                thread_id, data = self.updates.get_nowait()
            except Empty:
                return
            if thread_id is not None:
                if thread_id == self.selected:
                    self.details = data
                continue
            if data["connection"]["status"] != "connected":
                self.connection_error = view.clean(data["connection"]["error"])
                continue
            self.connection_error = ""
            self.updated_at = data["generated_at"]
            self.received_at = time.monotonic()
            self.thread_ids = [agent["id"] for agent in data["agents"]]
            self.agents = sorted(
                (agent for agent in data["agents"] if agent.get("tmux_panes")),
                key=lambda agent: (agent["cwd"].casefold(), agent["cwd"]),
            )
            self.reconcile_selection()

    def move(self, amount: int) -> None:
        """Move through tasks or scroll the focused details pane."""
        if self.details_focused:
            self.detail_scroll = max(
                0, min(self.detail_scroll + amount, max(0, self.detail_height - self.body_height))
            )
            return
        ids = [agent["id"] for agent in self.filtered()]
        if ids:
            index = ids.index(self.selected) if self.selected in ids else 0
            self.select(ids[max(0, min(index + amount, len(ids) - 1))])

    def set_filter(self, index: int) -> None:
        """Change the visible status category and preserve selection when possible."""
        self.filter_index = index % len(FILTERS)
        self.list_scroll = 0
        self.notice = ""
        self.reconcile_selection()

    def is_stale(self) -> bool:
        """Measure snapshot age independently of wall-clock adjustments."""
        return self.received_at is None or time.monotonic() - self.received_at > STALE_AFTER

    async def open_selected(self) -> None:
        """Recheck the pane mapping before leaving the popup."""
        if self.selected is None or self.opening:
            return
        if self.connection_error or self.is_stale():
            self.notice = "Status unavailable; wait for a fresh update"
            return
        self.opening = True
        try:
            command = await asyncio.to_thread(
                tmux.switch_command, self.selected, self.thread_ids, self.client
            )
            if not self.app.is_done:
                self.app.exit(result=command)
        except (OSError, ValueError) as exc:
            self.notice = view.clean(exc)
        finally:
            self.opening = False
            self.app.invalidate()

    def bindings(self) -> KeyBindings:
        """Define navigation keys without any text-filtering mode."""
        keys = KeyBindings()

        @keys.add("j")
        @keys.add("down")
        @keys.add("k")
        @keys.add("up")
        def move(event: KeyPressEvent) -> None:
            """Move one row in the focused pane."""
            self.move(1 if event.key_sequence[0].key in ("j", "down") else -1)

        @keys.add("h")
        @keys.add("left")
        @keys.add("l")
        @keys.add("right")
        def focus(event: KeyPressEvent) -> None:
            """Move focus between the task list and details."""
            self.details_focused = event.key_sequence[0].key in ("l", "right")
            if not self.details_focused:
                self.expanded = False

        @keys.add("tab")
        @keys.add("s-tab")
        def cycle_filter(event: KeyPressEvent) -> None:
            """Cycle status filters in either direction."""
            self.set_filter(self.filter_index + (1 if event.key_sequence[0].key == "c-i" else -1))

        @keys.add("c-f")
        def attention(event: KeyPressEvent) -> None:
            """Toggle between all threads and those needing attention."""
            self.set_filter(0 if self.filter_index == 1 else 1)

        @keys.add("pagedown")
        @keys.add("pageup")
        @keys.add("c-d")
        @keys.add("c-u")
        def page(event: KeyPressEvent) -> None:
            """Move by a page, or half a page with Ctrl-d and Ctrl-u."""
            key = event.key_sequence[0].key
            amount = max(1, self.body_height // (2 if key in ("c-d", "c-u") else 1))
            self.move(amount if key in ("pagedown", "c-d") else -amount)

        @keys.add("escape", "enter")
        def expand(event: KeyPressEvent) -> None:
            """Expand or restore the details pane."""
            self.expanded = not self.expanded
            self.details_focused = self.expanded

        @keys.add("enter")
        def open_thread(event: KeyPressEvent) -> None:
            """Resolve and open the selected conversation's tmux pane."""
            self.app.create_background_task(self.open_selected())

        @keys.add("escape")
        @keys.add("q")
        @keys.add("c-c")
        def close(event: KeyPressEvent) -> None:
            """Close the popup without switching panes."""
            self.app.exit()

        return keys

    def screen(self, width: int, height: int) -> list[StyleAndTextTuples]:
        """Lay out tabs, grouped tasks, details, and keyboard hints."""
        if width < 20 or height < 8:
            message: StyleAndTextTuples = [("class:muted", view.fit("Terminal too small", width))]
            return [message][:height]
        inner = max(1, width - 4)
        self.body_height = max(1, height - 7)
        stamp = time.strftime("%I:%M:%S %p", time.localtime(self.updated_at)).lstrip("0")
        subtitle = f"tmux · updated {stamp}" if self.updated_at else "tmux"
        lines: list[StyleAndTextTuples] = [
            [("class:title", "Codex agents"), ("class:muted", "  " + subtitle)],
            [],
        ]
        for index, (label, _) in enumerate(FILTERS):
            text = f" {label} {len(self.filtered(index))} "
            lines[1].extend(
                [("class:tab" if index == self.filter_index else "class:muted", text), ("", " ")]
            )
        if fragment_list_width(lines[1]) > inner:
            label = FILTERS[self.filter_index][0]
            lines[1] = [
                ("class:tab", f" {label} {len(self.filtered())} "),
                ("class:muted", "  Tab / Shift-Tab filter"),
            ]
        lines.append([("class:muted", "─" * inner)])
        split = inner >= 90 and not self.expanded
        only_details = self.expanded or (not split and self.details_focused)
        left_width = inner * 3 // 5 if split else inner
        right_width = inner - left_width - 3 if split else inner
        agents = self.filtered()
        rows: list[StyleAndTextTuples]
        rows, cursor = view.task_lines(agents, self.selected, left_width)
        if not rows:
            message = self.connection_error or (
                "No conversations open in this tmux server"
                if not self.agents
                else "No conversations match this filter"
            )
            rows = [[("class:muted", view.fit(message, left_width))]]
        self.list_scroll = max(0, min(self.list_scroll, cursor, len(rows) - self.body_height))
        if cursor >= self.list_scroll + self.body_height:
            self.list_scroll = cursor - self.body_height + 1
        selected = next((agent for agent in agents if agent["id"] == self.selected), None)
        details = view.detail_lines(selected, self.details, right_width)
        self.detail_height = len(details)
        self.detail_scroll = min(self.detail_scroll, max(0, len(details) - self.body_height))
        task_style = "class:muted" if self.details_focused else "class:title"
        detail_style = "class:title" if self.details_focused else "class:muted"
        heading: StyleAndTextTuples = (
            [(detail_style, "Task details")]
            if only_details
            else [(task_style, view.fit("Tasks", left_width))]
        )
        if split:
            heading += [("class:muted", " │ "), (detail_style, "Task details")]
        lines.append(heading)
        for index in range(self.body_height):
            task_row: StyleAndTextTuples = (
                rows[self.list_scroll + index] if self.list_scroll + index < len(rows) else []
            )
            detail_row = (
                details[self.detail_scroll + index]
                if self.detail_scroll + index < len(details)
                else []
            )
            if only_details:
                lines.append(detail_row)
            elif split:
                padding = max(0, left_width - fragment_list_width(task_row))
                lines.append(task_row + [("", " " * padding), ("class:muted", " │ ")] + detail_row)
            else:
                lines.append(task_row)
        lines.append([("class:muted", "─" * inner)])
        message = self.notice or self.connection_error
        if not message and self.updated_at and self.is_stale():
            message = "Status is stale; waiting for Codex"
        footer = (
            message
            or "j/k move · h/l focus · Tab filter · Ctrl-f needs you · Enter open · Esc close"
        )
        lines.append([("class:error" if message else "class:muted", view.fit(footer, inner))])
        lines.insert(0, [])
        return [[("", "  ")] + view.clip_line(line, inner) for line in lines]


def run(client: str) -> None:
    """Run the dashboard, then switch the invoking tmux client when requested."""
    picker = Picker(client)
    try:
        command = picker.app.run(pre_run=picker.start)
    finally:
        picker.stop()
    if command:
        os.execvp(command[0], command)
