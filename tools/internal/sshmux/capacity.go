package sshmux

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"time"
)

// Capacity checks room for up to want panes and one management channel.
// sshd does not advertise MaxSessions. Hold the probes simultaneously, and
// keep the destination locked until the real pane channels have opened.
func (d Destination) Capacity(ctx context.Context, want int) (int, error) {
	if want == 0 {
		return 0, nil
	}

	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	var (
		held []*probe
		err  error
	)

	for range want + 1 {
		var p *probe

		p, err = d.probe(ctx)
		if err != nil {
			if errors.Is(err, ErrChannelRefused) && len(held) > 0 {
				err = nil
			}

			break
		}

		held = append(held, p)
	}

	for _, p := range held {
		_, _ = io.WriteString(p.in, "\n")
		_ = p.in.Close()
	}

	for _, p := range held {
		if waitErr := p.cmd.Wait(); waitErr != nil && err == nil {
			err = d.commandError(waitErr, p.stderr.String())
		}
	}

	if err != nil {
		return 0, err
	}

	return len(held) - 1, nil
}

type probe struct {
	cmd    *exec.Cmd
	in     io.WriteCloser
	stderr bytes.Buffer
}

func (d Destination) probe(ctx context.Context) (*probe, error) {
	// EOF before release makes read fail, so an early exit cannot inflate capacity.
	cmd := exec.CommandContext(ctx, "ssh", d.Channel("-T", "exec sh -c 'printf +; read -r done'")...) // #nosec G204 -- Fixed command on the private master.
	cmd.WaitDelay = time.Second

	in, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("open probe stdin: %w", err)
	}

	out, err := cmd.StdoutPipe()
	if err != nil {
		_ = in.Close()
		return nil, fmt.Errorf("open probe stdout: %w", err)
	}

	p := &probe{cmd: cmd, in: in}
	cmd.Stderr = &p.stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start SSH probe: %w", err)
	}

	stop := context.AfterFunc(ctx, func() { _ = out.Close() })
	defer stop()

	var ready [1]byte
	if _, err := io.ReadFull(out, ready[:]); err != nil || ready[0] != '+' {
		_ = in.Close()

		if err := cmd.Wait(); err != nil {
			return nil, d.commandError(err, p.stderr.String())
		}

		return nil, fmt.Errorf("%w: missing SSH probe reply", os.ErrInvalid)
	}

	return p, nil
}
