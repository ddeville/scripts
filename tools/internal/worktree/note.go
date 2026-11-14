package worktree

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/ddeville/scripts/tools/internal/git"
)

const noteFile = "wt-note"

var errEditor = errors.New("EDITOR is not set")

func readNote(metadata *os.Root) string {
	data, err := metadata.ReadFile(noteFile)
	if err != nil {
		return ""
	}

	return strings.TrimSuffix(string(data), "\n")
}

// EditNote opens a copy of the note and saves changes after the editor exits.
func EditNote(ctx context.Context, item Info) error {
	editor := os.Getenv("EDITOR")
	if editor == "" {
		return errEditor
	}

	file, err := os.CreateTemp("", "wt-note-*.txt")
	if err != nil {
		return fmt.Errorf("create note draft: %w", err)
	}
	defer func() { _ = os.Remove(file.Name()) }()

	draft := item.Note
	if draft != "" {
		draft += "\n"
	}

	_, writeErr := file.WriteString(draft)
	if err := errors.Join(writeErr, file.Close()); err != nil {
		return fmt.Errorf("write note draft: %w", err)
	}

	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", editor+` "$@"`, "sh", file.Name()) // #nosec G204 G702 -- Run the user's editor command with the draft path as a separate argument.
	cmd.Dir = item.Path
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("edit worktree note: %w", err)
	}

	data, err := os.ReadFile(file.Name()) // #nosec G304 -- Reads the temporary file passed to the user's editor.
	if err != nil {
		return fmt.Errorf("read edited note: %w", err)
	}

	note := strings.TrimSpace(string(data))
	if note == strings.TrimSpace(item.Note) {
		return nil
	}

	return SetNote(item.Path, note)
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
