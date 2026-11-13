package cli_test

import (
	"bufio"
	"context"
	"errors"
	"os"
	"os/exec"
	"syscall"
	"testing"
	"time"

	"github.com/spf13/cobra"

	"github.com/ddeville/scripts/tools/internal/cli"
)

func TestExecuteSignals(t *testing.T) {
	t.Parallel()

	if mode := os.Getenv("SCRIPTS_TEST_SIGNAL_CHILD"); mode != "" {
		signalChild(mode)
		return
	}

	for _, tc := range []struct {
		name string
		sig  os.Signal
		code int
	}{
		{name: "interrupt", sig: os.Interrupt, code: 130},
		{name: "terminate", sig: syscall.SIGTERM, code: 143},
		{name: "force", sig: os.Interrupt, code: -1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
			defer cancel()

			cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestExecuteSignals$") // #nosec G204 G702 -- Runs this test binary, never user-supplied code.

			cmd.Env = append(os.Environ(), "SCRIPTS_TEST_SIGNAL_CHILD="+tc.name)
			cmd.Stderr = os.Stderr
			cmd.WaitDelay = time.Second

			output, err := cmd.StdoutPipe()
			if err != nil {
				t.Fatal(err)
			}

			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}

			t.Cleanup(func() {
				if cmd.ProcessState == nil {
					_ = cmd.Process.Kill()
					_ = cmd.Wait()
				}
			})

			lines := bufio.NewScanner(output)
			if !lines.Scan() || lines.Text() != "ready" {
				t.Fatal("command did not start")
			}

			if err := cmd.Process.Signal(tc.sig); err != nil {
				t.Fatal(err)
			}

			if !lines.Scan() || lines.Text() != "canceled" {
				t.Fatal("signal did not cancel the command context")
			}

			if tc.name == "force" {
				if err := cmd.Process.Signal(tc.sig); err != nil {
					t.Fatal(err)
				}
			}

			var exit *exec.ExitError
			if err := cmd.Wait(); !errors.As(err, &exit) || exit.ExitCode() != tc.code {
				t.Fatalf("exit = %v, want code %d", err, tc.code)
			}

			if tc.name == "force" {
				status, ok := exit.Sys().(syscall.WaitStatus)
				if !ok || status.Signal() != tc.sig {
					t.Fatalf("second signal did not force exit: %v", exit.Sys())
				}
			}
		})
	}
}

func signalChild(mode string) {
	cmd := &cobra.Command{
		Use: "signal-test", SilenceErrors: true, SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.Println("ready")
			<-cmd.Context().Done()
			cmd.Println("canceled")

			if mode == "force" {
				select {}
			}

			return cmd.Context().Err()
		},
	}
	cmd.SetArgs(nil)
	cmd.SetOut(os.Stdout)
	os.Exit(cli.Execute(cmd))
}
