package tmux

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
)

func run(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "tmux", args...) // #nosec G204 G702 -- Arguments are separate; callers explicitly supply any window shell command.

	var stderr bytes.Buffer

	cmd.Stderr = &stderr

	output, err := cmd.Output()
	if err != nil {
		detail := strings.TrimSpace(string(output) + stderr.String())
		return detail, fmt.Errorf("tmux %s: %w: %s", args[0], err, detail)
	}

	return string(output), nil
}

func switchClient(ctx context.Context, target, client string) error {
	args := []string{"switch-client", "-t", target}
	if client != "" {
		args = append(args, "-c", client)
	}

	_, err := run(ctx, args...)

	return err
}
