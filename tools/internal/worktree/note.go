package worktree

import (
	"crypto/rand"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/ddeville/scripts/tools/internal/git"
)

const noteFile = "wt-note"

func readNote(metadata *os.Root) string {
	data, err := metadata.ReadFile(noteFile)
	if err != nil {
		return ""
	}

	return strings.TrimSuffix(string(data), "\n")
}

// SetNote replaces the note for a linked checkout.
func SetNote(path, note string) error {
	note = strings.TrimSpace(note)
	if note == "" {
		return fmt.Errorf("%w: note is empty; use --clear to remove it", os.ErrInvalid)
	}

	metadata, err := git.OpenWorktreeMetadata(path)
	if err != nil {
		return fmt.Errorf("set worktree note: %w", err)
	}
	defer func() { _ = metadata.Close() }()

	temp := "." + noteFile + "-" + rand.Text()

	file, err := metadata.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return fmt.Errorf("create temporary note: %w", err)
	}
	defer func() { _ = metadata.Remove(temp) }()

	_, writeErr := file.WriteString(note + "\n")
	if err := errors.Join(writeErr, file.Close()); err != nil {
		return fmt.Errorf("write worktree note: %w", err)
	}

	if err := metadata.Rename(temp, noteFile); err != nil {
		return fmt.Errorf("replace worktree note: %w", err)
	}

	return nil
}

// ClearNote removes the note for a linked checkout, if present.
func ClearNote(path string) error {
	metadata, err := git.OpenWorktreeMetadata(path)
	if err != nil {
		return fmt.Errorf("clear worktree note: %w", err)
	}
	defer func() { _ = metadata.Close() }()

	if err := metadata.Remove(noteFile); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("clear worktree note: %w", err)
	}

	return nil
}
