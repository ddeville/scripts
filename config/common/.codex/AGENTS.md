# Global Agent Instructions

- When running Git commands, disable fsmonitor for that command to avoid spawning persistent fsmonitor daemons from agent activity.
- Use: `git -c core.fsmonitor=false <subcommand> ...`
- Do not change the user's global or repository fsmonitor configuration unless explicitly asked.
