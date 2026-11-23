package remote

import (
	"fmt"

	"golang.org/x/sys/unix"
)

func flushInput() error {
	if err := unix.IoctlSetInt(0, unix.TCFLSH, unix.TCIFLUSH); err != nil {
		return fmt.Errorf("flush pane input: %w", err)
	}

	return nil
}
