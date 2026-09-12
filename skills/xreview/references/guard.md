## Stop-hook guard (`xreview-guard.py`)

When the guard blocks you, you get an additionalContext block starting `[xreview guard] ... Do not finish up`, listing the plan files that are not stamped — run the flow above as it says, do not work around it.

- The guard **only activates under a directory tree that contains a `.xreview-guard` file** (opt-in). It performs no review of its own, it only knows the marker.
- Block conditions: the file was touched with Write/Edit in this session, it matches a glob in `.xreview-guard`, and it lacks a current hash-valid PASS or explicit final-line SKIP.
- An empty `.xreview-guard` file means the built-in globs (`PLAN*.md`, `plan*.md`, `*_PLAN.md`, `*-plan.md` ...); to change the scope, put one glob per line in it.
- User says a given file does not need review -> write one line `XREVIEW-SKIP <reason>` at the end of that file (the guard accepts that as a human exemption, not as PASS).
- User says "turn the guard off for now" -> put a single line `off` in `.xreview-guard` (that directory only), or have them `export XREVIEW_GUARD=0` (global).
