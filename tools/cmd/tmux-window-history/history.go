package main

import (
	"slices"
	"strconv"
	"strings"
)

type history struct {
	visits []string
	cursor int
}

type direction int

const (
	backward direction = -1
	forward  direction = 1
)

func parseHistory(value string) history {
	// Attached clients may have history stored as back|current|forward.
	if back, rest, ok := strings.Cut(value, "|"); ok {
		current, forward, _ := strings.Cut(rest, "|")
		visits := strings.Fields(back)
		slices.Reverse(visits)
		cursor := len(visits)
		visits = append(visits, current)

		return history{visits: append(visits, strings.Fields(forward)...), cursor: cursor}
	}

	index, entries, _ := strings.Cut(value, " ")
	cursor, err := strconv.Atoi(index)
	visits := strings.Fields(entries)
	if err != nil || cursor < 0 || cursor >= len(visits) {
		return history{}
	}

	return history{visits: visits, cursor: cursor}
}

func (h history) String() string {
	if len(h.visits) == 0 {
		return ""
	}

	return strconv.Itoa(h.cursor) + " " + strings.Join(h.visits, " ")
}

func (h history) current() string {
	if len(h.visits) == 0 {
		return ""
	}

	return h.visits[h.cursor]
}

func (h *history) visit(location string) {
	if location == h.current() {
		return
	}

	// Discard the forward branch and retain up to 100 previous visits.
	end := min(h.cursor+1, len(h.visits))
	h.visits = append(h.visits[max(0, end-100):end], location)
	h.cursor = len(h.visits) - 1
}

func (h *history) move(dir direction, selectWindow func(string) bool) {
	for {
		next := h.cursor + int(dir)
		if next < 0 || next >= len(h.visits) {
			return
		}

		destination := h.visits[next]
		if destination != h.current() && selectWindow(destination) {
			h.cursor = next
			return
		}

		// A window may have closed or been unlinked since the visit.
		h.visits = slices.Delete(h.visits, next, next+1)
		if next < h.cursor {
			h.cursor--
		}
	}
}
