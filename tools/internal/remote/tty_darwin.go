package remote

import (
	"fmt"

	"golang.org/x/sys/unix"
)

func flushInput() error {
	if err := unix.IoctlSetPointerInt(0, unix.TIOCFLUSH, 1); err != nil {
		return fmt.Errorf("flush pane input: %w", err)
	}
	return nil
}
