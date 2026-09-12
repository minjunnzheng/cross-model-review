## Other commands

| Command | Purpose |
|---|---|
| `xreview status --session <dir>` | round count / latest verdict / `state:` = is the round still running, dead, or finished |
| `xreview log --session <dir>` | print every round in full |
| `xreview check <file>` | hash-valid final-line XREVIEW-PASS or explicit final-line XREVIEW-SKIP -> exit 0 |
| `xreview start -` | read the material to review from stdin |

Environment variables: `XREVIEW_REVIEWER` (`codex` | `claude` | `grok`), `XREVIEW_AUTHOR` (explicit author family when harness detection is missing or inherited through a multiplexer), `XREVIEW_CODEX_MODEL` / `XREVIEW_GROK_MODEL` (default `grok-4.6`) / `XREVIEW_CLAUDE_MODEL` (reviewer model, per engine), `XREVIEW_SESSION`, `XREVIEW_TIMEOUT` (per-round timeout, default 900s), and `XREVIEW_ALLOW_SELF=1` (allow same-family review — last resort when only one model CLI is installed).
