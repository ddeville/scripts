package agents

import (
	"path/filepath"
	"strings"
)

// InDirectory selects conversations in a checkout or one of its subdirectories.
func InDirectory(items []Agent, directory string) []Agent {
	if directory == "" {
		return nil
	}

	directory = canonicalDirectory(directory)

	var matches []Agent

	for _, item := range items {
		if item.Cwd == "" {
			continue
		}

		relative, err := filepath.Rel(directory, canonicalDirectory(item.Cwd))
		if err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			matches = append(matches, item)
		}
	}

	return matches
}

func canonicalDirectory(path string) string {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return resolved
	}

	return filepath.Clean(path)
}
