---
name: xreview
description: "Cross-model review loop — hand a plan, proposal or script to a different model family (Codex by default; Claude or Grok as alternatives) as the reviewer and trade rounds inside one reviewer session, fixing what should be fixed and pushing back where it is wrong, until both sides genuinely reach consensus; only then is the XREVIEW-PASS marker stamped. Use when the user says 'cross-review this', 'have another model review this', 'get Codex to check this', 'get Grok to review this', 'review it until we agree', 'xreview', or before implementing a non-trivial plan, before an expensive computation run, before writing AI output into any trusted store (reference library, notes, knowledge base), or before a major method or architecture choice. NOT for: one-line changes; plain factual lookups; a one-shot 'who is right' ruling (use ai-duel)."
---

# xreview — cross-model review loop

**You are the author, another model family is the reviewer.** The same head checking its own work always has blind spots; only a different model family, looking at it from the outside, catches them.

Tool: `xreview` (must be on PATH; see the package README). It handles every reviewer call — **do not assemble codex/grok/claude commands yourself**.

## Picking the reviewer

Default is Codex; the tool refuses to let the author's own family review (`✗ The author is claude, so claude cannot be the reviewer`), so you never need to work out who is running.

| Reviewer | How | When |
|---|---|---|
| Codex (default) | nothing to set | the standing choice — strongest at code, config and plan mechanics |
| Claude | automatic when the author is Codex; or `--reviewer claude` | Codex is the author, or Codex is out of quota |
| Grok 4.6 | `xreview start --reviewer grok …` | user asks for Grok; a second opinion after a Codex PASS you distrust; Codex is out of quota |

Pick the engine once, at `start`, as `--reviewer ENGINE[:MODEL]` — e.g. `--reviewer grok:grok-4.6`, `--reviewer claude:opus` (`XREVIEW_REVIEWER` works too; the flag wins). Engine and model are pinned into the session, so `round` and `stamp` need nothing set. Model precedence: `-m`, then `:MODEL`, then the per-engine `XREVIEW_*_MODEL` variables.

## Why it is shaped this way (do not optimise these away)

1. **The same codex thread throughout.** A reviewer that cold-starts every round keeps inventing new small defects, so you never finish fixing -> over-engineering. The same thread remembers what it said last round: round 1 finds the real problems, later rounds sign off on your fixes, and that is what converges. `xreview round` resumes that same thread — do not bypass it.
2. **No round limit.** A limit forces the worst outcome: on the last round the reviewer pretends there is nothing wrong just to end it. There is exactly one pass criterion — **consensus**.
3. **The marker is the handshake.** Only a PASS can be stamped; `xreview stamp` refuses every non-PASS verdict and has no force override. The marker is bound to the exact reviewed snapshot, so editing the target after PASS requires another round.

## Flow

### 0. Decide the target and the cwd
- Plan file already exists -> use that file.
- Plan still only in the conversation -> write it out as an md file first (project directory or scratchpad), **then** submit it. The reviewer has to be able to re-read the file to see what you changed.
- **Keep cwd fixed at the project root**: the `.xreview/` state directory is relative to cwd, so changing directory mid-loop loses the session. (Inside a git repo, add `.xreview/` to `.gitignore`.)

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
Round 1 takes **3–15 minutes and prints nothing until it returns** — the reviewer has read-only file access and spends that time reading the source and data files you cite.

> **Never abandon a round in flight.** A silent, long-running command looks exactly like a failed one. In Codex, `exec_command` comes back with `Script running with cell ID N` once `yield_time_ms` elapses — **that means it is still running**: poll the same cell (or pass a `yield_time_ms` of 900000) until it really completes. Never start a second session, and never switch reviewer engine, because the first one "returned nothing".
>
> If you are unsure, run `xreview status --session <dir>` and read the `state:` line — `RUNNING` = alive, keep waiting; `INCOMPLETE` = the process was killed mid-round, so the blank verdict is **not** a review result; `done` = what you see is the real verdict. Abandoning a silent round at ~10 s and re-firing it costs twice as much and produces nothing.

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
Repeat 2–3 until the verdict is PASS. Typically 3–5 rounds.

**Handling a real deadlock**: the same dispute runs 3 rounds in a row with neither side giving ground and both sides giving concrete reasons -> stop, and hand the user one sentence for each side to decide on. **That is the only legitimate exit** — do not fake consensus to end it.

### 5. Stamp
```
xreview stamp --session <dir>
```

## How to report to the user

The user's job is to sit there and wait while the two of you argue — do not paste every round's full text at them. One line per round:

```
Round N: X findings -> Y fixed, Z pushed back, W unresolved
```

At the end report: total rounds, which substantive things actually changed (<=5 items), and where it was stamped. Only use `xreview log` when the user wants the details.

## Other commands

| Command | Purpose |
|---|---|
| `xreview status --session <dir>` | round count / latest verdict / `state:` = is the round still running, dead, or finished |
| `xreview log --session <dir>` | print every round in full |
| `xreview check <file>` | hash-valid final-line XREVIEW-PASS or explicit final-line XREVIEW-SKIP -> exit 0 |
| `xreview start -` | read the material to review from stdin |

Environment variables: `XREVIEW_REVIEWER` (`codex` | `claude` | `grok`), `XREVIEW_AUTHOR` (explicit author family when harness detection is missing or inherited through a multiplexer), `XREVIEW_CODEX_MODEL` / `XREVIEW_GROK_MODEL` (default `grok-4.6`) / `XREVIEW_CLAUDE_MODEL` (reviewer model, per engine), `XREVIEW_SESSION`, `XREVIEW_TIMEOUT` (per-round timeout, default 900s), and `XREVIEW_ALLOW_SELF=1` (allow same-family review — last resort when only one model CLI is installed).

## Cost

Each round the reviewer reads a fair number of files: roughly 1–2M input tokens (mostly cache hits) and ~20k output. Four rounds is the same order of magnitude as one full code review — cheaper than debugging it afterwards, but do not use it to review a one-line change.

## Stop-hook guard (`xreview-guard.py`)

When the guard blocks you, you get an additionalContext block starting `[xreview guard] ... Do not finish up`, listing the plan files that are not stamped — run the flow above as it says, do not work around it.

- The guard **only activates under a directory tree that contains a `.xreview-guard` file** (opt-in). It performs no review of its own, it only knows the marker.
- Block conditions: the file was touched with Write/Edit in this session, it matches a glob in `.xreview-guard`, and it lacks a current hash-valid PASS or explicit final-line SKIP.
- An empty `.xreview-guard` file means the built-in globs (`PLAN*.md`, `plan*.md`, `*_PLAN.md`, `*-plan.md` ...); to change the scope, put one glob per line in it.
- User says a given file does not need review -> write one line `XREVIEW-SKIP <reason>` at the end of that file (the guard accepts that as a human exemption, not as PASS).
- User says "turn the guard off for now" -> put a single line `off` in `.xreview-guard` (that directory only), or have them `export XREVIEW_GUARD=0` (global).

## Division of labour with the sibling tools

- **xreview** (this tool) = iterate to consensus; the subject is "a plan or script that will be implemented", the product is a stamped final version.
- **`ai-duel`** = one-shot; both sides answer independently, peer-critique, then a blind verdict; the subject is "an open question", the product is "which option is better".
- **`ai-review`** = anti-flattery review of a piece of writing (multiple lenses + rebuttal round); the subject is "an article written for humans".
- Bibliography verification is out of scope. Do not treat an xreview PASS as a DOI check.
