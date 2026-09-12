## Flow

### 0. Decide the target and the cwd
- Plan file already exists -> use that file.
- Plan still only in the conversation -> write it out as an md file first (project directory or scratchpad), **then** submit it. The reviewer has to be able to re-read the file to see what you changed.
- **Keep one working directory throughout the review.** `.xreview/` is relative to cwd. Use the session scratchpad when project rules require temporary artifacts outside the repo, and reference project files by absolute path. If the project permits review artifacts inside its repo, exclude `.xreview/` in `.gitignore`.

### 1. Open the review
```
xreview start --label <short-name> <plan file>
xreview start --label ui -i shot-desktop-1440.png -i shot-ipad-1024.png proposal.md
```

The command prints an absolute session directory. Copy it and either add
`--session <that-directory>` to every later command or export
`XREVIEW_SESSION=<that-directory>`. Never guess a session through a shared
pointer; parallel reviews in one project are supported only because sessions
are explicit.
A review may take several minutes without producing a final reply. Silence alone does not mean that it failed.

- Follow the current execution tool's schema and the handle it actually returns. With `exec_command`, resume a running `session_id` using `write_stdin`. With `functions.exec`, use `functions.wait` only after it returns `Script running with cell ID ...`, passing that `cell_id`. These handles are not interchangeable.
- Keep individual waits within the tool's supported limits and short enough to provide the required progress updates. Continue polling the existing run; do not launch another reviewer merely because a call yielded.
- If execution state is unclear, run `xreview status --session <dir>`. `RUNNING` means the review is active; `INCOMPLETE` means the round was interrupted and its missing verdict is not a result; `done` means it completed. Report an actual failure or required user action instead of treating silence as a verdict.

**Always attach screenshots for anything visual.** The reviewer can read the source but cannot see the rendered result — with no image it is completely blind to "this block collapses into a heap on iPad". Take shots at desktop width and at the target device width, plus one for each key interaction state; `-i` can be repeated. **The filename is the caption**, so give it a meaningful name (`shot-ipad-1024.png`, `shot-field-form.png`), not `Screenshot 2026-07-30.png`. After fixing, attach the re-taken shots with `xreview round --session <dir> -i new-shot.png -` and it will check them.

### 2. Handle findings point by point (the author's iron rule)
Every finding has exactly two exits, **a third one is not allowed**:

- **Fix it** -> edit the plan file directly (use Edit, do not just promise it in your reply).
- **Push back** -> give a concrete reason or evidence and convince the reviewer instead.

Forbidden:
- Pretending a problem does not exist, glossing over it, or treating "later" as having handled it.
- Over-engineering the reviewer never asked for, just to get through faster.
- **Accepting the reviewer's factual claims without checking them.** It will cite the wrong line number and misremember key names. When it says "file X line N is Y", Read/Grep to check first; if it is wrong, push back with the actual content — that is your job, not insubordination.
- Appending a patch at the end of the file while leaving the contradictory old sentence above it (the reviewer will catch it and you waste a round).

### 3. Send the next round
Feed long replies from stdin with a heredoc:
```
xreview round --session <dir> - <<'EOF'
Point by point:
1. <item> -> fixed, see plan item N / file:line
2. <item> -> pushing back: <reason and evidence>. If you still insist, say exactly what you are insisting on under <assumption>.
EOF
```
`xreview round` attaches the plan file's diff automatically, so you do not need to re-paste the full text.

### 4. Converge
Repeat steps 2–3 until the verdict is PASS.

**Handling a real deadlock**: the same dispute runs 3 rounds in a row with neither side giving ground and both sides giving concrete reasons -> stop, and hand the user one sentence for each side to decide on. **That is the only legitimate exit** — do not fake consensus to end it.

### 5. Stamp
```
xreview stamp --session <dir>
```
