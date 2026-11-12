// Package cli provides shared command-line validation.
package cli

import (
	"errors"
	"fmt"
	"strings"

	"github.com/spf13/cobra"
)

var errMissingArgument = errors.New("missing required argument")

// ExactArgs validates named positional arguments and includes usage on failure.
func ExactArgs(names ...string) cobra.PositionalArgs {
	return func(cmd *cobra.Command, args []string) error {
		if len(args) < len(names) {
			return fmt.Errorf("%w: %s; usage: %s", errMissingArgument, strings.Join(names[len(args):], ", "), cmd.UseLine())
		}

		if err := cobra.ExactArgs(len(names))(cmd, args); err != nil {
			return fmt.Errorf("%w; usage: %s", err, cmd.UseLine())
		}

		return nil
	}
}
