# Cross-model Review Gates

Three skills and three CLIs for cases where an AI's self-review is not enough.
A different model family reviews the work, `xreview` binds PASS to the exact
reviewed snapshot, `ai-duel` compares two cold answers claim by claim, and
`ai-review` filters manuscript criticism through a rebuttal round.

The markers are tamper-evident audit records, not signatures. They detect stale
content and keep PASS distinct from an explicit human `XREVIEW-SKIP`, but a
writer with file access can still forge text and a digest. See
[SECURITY.md](SECURITY.md) for the boundary.

> **Name collision:** [24kchengYe/cross-model-review](https://github.com/24kchengYe/cross-model-review)
> is a separate OpenRouter-based project with the same repository name. This
> project keeps the identifier for compatibility and uses **Cross-model Review
> Gates** as its human-facing name. See the [tool landscape](docs/landscape.md).

Nothing here hard-codes a home directory. Paths resolve through `~/bin`
and the usual skill directories (`~/.claude/skills`, `~/.codex/skills`,
`~/.agents/skills`). Registering the optional Stop hook in Claude Code
`settings.json` is the one place that needs an absolute path — Claude
Code does not expand `~` there.

| Item | What it does | Needs |
|---|---|---|
| `xreview` | Cross-model review loop: hand a plan to a different model family, exchange rounds in one persistent reviewer thread, stamp the exact reviewed snapshot only on consensus | **Two model families**: the reviewer (`codex` by default; `claude` / `grok` as alternatives) must differ from the author's. With only `claude` installed, a Claude Code session can review only via `XREVIEW_ALLOW_SELF=1` — which defeats the point |
| `ai-duel` | Same question to two models, both cold, one peer-critique round, then a double-blind claim-level verdict | `claude` + `codex` for the full duel; `-q claude` / `-q codex` quick follow-up needs only the named CLI |
| `ai-review` | Anti-flattery manuscript review: author anonymised, 4 lenses in parallel, rebuttal round, revised draft | `claude` + `codex` for the full run; `-q` quick mode needs `claude` only |
| `hooks/xreview-guard.py` | Stop hook: refuses to let a Claude Code session finish while a plan file has no PASS marker. Inert until you drop a `.xreview-guard` file in a directory | Claude Code |

---

## Install

### Claude Code (plugin)

```
/plugin marketplace add minjunnzheng/cross-model-review
/plugin install cross-model-review@cross-model-review
```

The plugin puts `xreview`, `ai-duel` and `ai-review` on the Bash tool's
PATH for that session, and loads the three skills (namespaced as
`/cross-model-review:xreview` and so on). The Stop hook ships with the
plugin and stays inert until a directory contains `.xreview-guard`.

You still want the CLIs on your own PATH so Codex, Grok, and a plain
terminal can call them:

```bash
git clone https://github.com/minjunnzheng/cross-model-review.git
cd cross-model-review
./install.sh            # CLIs -> ~/bin, skills -> ~/.claude / ~/.codex / ~/.agents
# ./install.sh --hooks  # also install xreview-guard.py -> ~/.claude/hooks
```

### Codex / Grok / a terminal (no plugin)

```bash
git clone https://github.com/minjunnzheng/cross-model-review.git
cd cross-model-review
./install.sh
# ./install.sh --hooks  # also install xreview-guard.py -> ~/.claude/hooks
#                       # (only useful if you also run Claude Code; see the Stop hook section)
```

`~/bin` must be on PATH. Codex reads `~/.codex/skills/<name>/` as a real
directory containing a real `SKILL.md` (a file-level symlink of
`SKILL.md` is silently ignored). Grok and other Agent Skills harnesses
read `~/.agents/skills/`. Open a new session and type `/` to confirm the
three skills appear.

The installer checks every destination before its first write. A differing
file or a skill directory with stale entries stops the whole install without
partial changes. `./install.sh --replace` explicitly moves conflicts into a
timestamped backup under `~/.local/state/cross-model-review/backups/` before
installing exact copies.

---

## Try it without spending model quota

`tests/fixtures/` ships a fake `claude` CLI that answers instantly with a
canned verdict, controlled by `FAKE_REVIEW_MODE` (`pass` / `changes` /
`no-verdict` / `fail`). It exercises the whole xreview loop — session
directories, stamping, `check`, the Stop hook — with zero model calls:

```bash
cd "$(mktemp -d)" && echo demo plan > PLAN.md
env PATH="/path/to/cross-model-review/tests/fixtures:$PATH" \
  XREVIEW_AUTHOR=codex XREVIEW_REVIEWER=claude FAKE_REVIEW_MODE=pass \
  xreview start --label demo PLAN.md
```

`tests/smoke.zsh` runs the full deterministic suite the same way.

---

## Which tool

- **xreview** — iterate to consensus. Subject: a plan or script that will
  be implemented. Product: a snapshot-bound PASS marker. Default reviewer is
  Codex; the tool refuses to let the author's detected family review.
- **ai-duel** — one-shot. Both sides answer independently, peer-critique,
  then a blind verdict. Subject: an open question. Product: which option
  holds up. `-q claude` / `-q codex` asks a single model a quick follow-up,
  skipping the critique and verdict rounds.
- **ai-review** — anti-flattery review of writing meant for humans
  (multiple lenses + rebuttal round). Not a plan, not code. `-q` runs a
  single-reviewer quick pass.

A coding task where two models would edit the same file is none of these:
isolate them in two git worktrees instead.

---

## Output language

The three tools answer in **English by default**. To switch, set
`AI_LANG` — or the per-tool override `AI_DUEL_LANG` / `AI_REVIEW_LANG` /
`XREVIEW_LANG`, which wins over it:

```bash
export AI_LANG=zh-TW      # Traditional Chinese
export AI_LANG=ja         # anything else: "Answer in ja."
```

This only controls what the **models** write. CLI help text and progress
lines are always English.

Verdict sentinels stay ASCII in every output language. `xreview` accepts a
verdict only when the final non-blank line is exactly `VERDICT: PASS` or
`VERDICT: CHANGES-REQUESTED`; translated or body-embedded lookalikes do not
control the gate.

---

## Optional project context

`ai-duel` and `ai-review` can be told where your project status lives, so
they check claims about your own work against something real instead of
guessing:

```bash
export AI_DUEL_CONTEXT_FILE="$HOME/notes/projects-index.md"
export AI_REVIEW_CONTEXT_FILE="$HOME/notes/projects-index.md"
```

Unset, or pointing at a file that does not exist, means nothing is
injected — no warning, no mention. That silence is deliberate (a missing
file must not break a run) but it cuts both ways: a typo in the path is
indistinguishable from not setting it, so check the value if a run seems
to ignore your project context.

Transcript filing is likewise optional: `AI_DUEL_VAULT` / `AI_REVIEW_VAULT`
(default `~/notes`). If the directory is absent nothing is written and
the run still succeeds, with the working files left in `.ai-duel/<timestamp>/`
or `.ai-review/<timestamp>/` under whatever directory you ran the command
in.

---

## Timeouts and wreckage

Every model call is capped on wall-clock time — `XREVIEW_TIMEOUT` (900s),
`AI_DUEL_TIMEOUT` (900s), `AI_REVIEW_TIMEOUT` (600s). A call that exceeds
its cap is killed and the run continues with whatever the other reviewers
returned, saying on stderr which ones were lost. This matters because a
CLI that is out of quota does not always fail fast: one observed run sat
on two hung calls for seven hours.

Every stage also checks that what came back is a **result** rather than
an error message. A CLI that is out of quota exits **successfully** and
writes its provider's error text into the output file, so "the file
exists and is non-empty" proves nothing at all. Without the check, that
error string flows onward as if it were a review finding, a calibration,
or a verdict.

So each stage has an acceptance test rather than an existence test:

| Stage | Counted only when |
|---|---|
| `ai-review` lens | the output carries the verdict line the charter demands |
| `ai-review` checker | it actually marks findings upheld / overstated / rejected |
| `ai-review` editor | the final report carries a verdict |
| `ai-duel` contestant | a real answer arrived from both sides (a duel needs two) |
| `ai-duel` judge | at least two judges returned a verdict |
| `xreview` round | the reviewer exits successfully, returns a thread, and ends with an exact verdict sentinel |

Whatever fails is named on stderr and the artifacts stay on disk. `xreview`
prints the last 20 lines of raw output and stderr, marks the run failed, and
returns non-zero; it never installs a failed run as an implicit current
session. Re-run the failed stage instead of repeating completed work.

---

## What these tools read, and where it goes

The three tools run model CLIs with **read access to your filesystem**, and
the models can use it. In a live test whose
question mentioned no file at all — it was an abstract design question —
the two contestants went and read the local `~/bin/xreview`, a global
Claude config, and a file under the user's notes directory, then quoted
all three with line numbers into the transcript.

That is usually what you want: it is why the reviewer can say "your line
71 already does this" instead of speculating. But be aware of the
consequence:

- Anything the models decide is relevant can end up in the transcript,
  including files you did not mention.
- With `AI_DUEL_NEUTRAL` set, that transcript is then sent to a
  **third-party provider** (xAI or Google) for the neutral verdict. This
  is the reason the neutral judge is opt-in rather than auto-detected.

If you work with material that must not leave your machine, run these
tools from a directory that does not contain it, and leave
`AI_DUEL_NEUTRAL` unset.

---

## xreview reviewer engines

Default is Codex. The tool detects the author's family
(`$CODEX_SANDBOX` / `$CODEX_THREAD_ID` = codex, `$GROK_AGENT` = grok,
`$CLAUDECODE` = claude) and refuses to let that family review — otherwise
it is one brain marking its own homework. Identity unreadable (a plain
terminal) fails open. Force self-review with `XREVIEW_ALLOW_SELF=1`.

| Reviewer | How | When |
|---|---|---|
| Codex (default) | nothing to set | standing choice — strongest at code, config and plan mechanics |
| Claude | automatic when the author is Codex; or `--reviewer claude` | Codex is the author, or Codex is out of quota |
| Grok 4.6 | `--reviewer grok` | a second opinion after a Codex PASS you distrust; Codex is out of quota |

Pick the engine once, at `start`, as `--reviewer ENGINE[:MODEL]` —
`xreview start --reviewer grok:grok-4.6 plan.md` (`XREVIEW_REVIEWER`
works too; the flag wins). The engine and model are pinned into the
session, so `round` and `stamp` need nothing set. Model precedence:
`-m MODEL`, then the `:MODEL` half of `--reviewer`, then
`XREVIEW_CODEX_MODEL` / `XREVIEW_CLAUDE_MODEL` / `XREVIEW_GROK_MODEL`.

How a spec resolves:

| Spec | Engine | Reviewer model |
|---|---|---|
| *(nothing)* | codex (claude when the author is codex) | the engine's own default |
| `--reviewer codex` | codex | codex's own default (`~/.codex/config.toml`) |
| `--reviewer grok:grok-4.6` | grok | grok-4.6 |
| `--reviewer claude:opus` | claude | opus |
| `--reviewer codex -m gpt-5.3-codex-spark` | codex | gpt-5.3-codex-spark (`-m` wins over `:MODEL`) |

The resolved engine and model are recorded in the session `meta` and in the
final `XREVIEW-PASS` marker (`reviewer=<engine>/<model>`), so a stamped plan
always says who reviewed it. There is no `reasoning`/`speed` half in the
spec on purpose: only the codex CLI exposes such knobs, and a knob that two
of the three engines silently ignore is worse than no knob.

`start` prints a unique run directory. Every later command requires that
directory through `--session` or `XREVIEW_SESSION`; there is no shared
`.xreview/current` pointer to race with another review:

```bash
xreview start --label auth plan.md
xreview round --session /absolute/path/to/.xreview/<run> -   # "-" reads your reply from stdin
xreview status --session /absolute/path/to/.xreview/<run>
xreview stamp --session /absolute/path/to/.xreview/<run>
```

`stamp` succeeds only when the target bytes still match the `snapshot-rN`
that produced PASS. The final marker stores that snapshot's SHA-256 digest;
`xreview check` and the Stop hook reject later edits. There is no force-PASS
option.

A round takes **3–15 minutes and prints nothing until it returns**. Do
not abandon it and start a replacement session. `xreview status --session
<run-directory>` reports `RUNNING` / `INCOMPLETE` / `done`.

---

## The optional Stop hook

A hook does not take effect just because the file exists. The plugin
install registers it automatically. For a manual install, add it to
`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.claude/hooks/xreview-guard.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`command` must be an absolute path — replace `/Users/you` with your real home
directory (Claude Code does not expand `~` here). If you already have a `hooks` block,
merge into it — do not replace it. If nothing happens after registering,
open `/hooks` once to reload the config, or restart the session.

The guard **only activates under a directory tree that contains a
`.xreview-guard` file** (opt-in), and it checks only files the session
actually touched: candidate targets are the Write/Edit calls recorded in the
session transcript, filtered by the globs below — it does not scan the
directory for unstamped plans. An empty file means the built-in globs
(`PLAN*.md`, `plan*.md`, `*_PLAN.md`, `*-plan.md`, plus a few
Traditional-Chinese filename patterns). To change the scope, put one
glob per line in it. A single line `off` disables the guard for that
directory; `export XREVIEW_GUARD=0` disables it globally.

A matched plan must end with a current, digest-valid `XREVIEW-PASS` marker or
an explicit final-line `XREVIEW-SKIP`. Missing, unreadable, unstamped, and stale
matched targets block. Malformed hook input or an internal hook exception
fails open so a broken integration cannot permanently trap a session.

Codex has no hook mechanism. The written skill is the whole gate there.

---

## The one thing you should change

The **mandatory checklist** inside the reviewer charter (search
`bin/xreview` for `[Mandatory checklist]`) currently ships a generic
version. That section is what points the reviewer at the failure modes
that actually recur in your work. Rewriting it for your own field is the
highest-leverage change you can make here.

After installing, the file to edit is **`~/bin/xreview`** — editing the
copy in this repo has no effect on the installed tool. A Claude Code
plugin install uses the copy inside the plugin cache; bump
`version` in `.claude-plugin/plugin.json` when you publish a rewrite, or
edit the cached copy knowing the next update will overwrite it.

The rest of the charter (no praise, no hunting for problems to look
useful, the BLOCKER threshold) is domain-independent; leave it alone.

---

## Principles

**A model checking its own work cannot see its own blind spots.**
xreview and ai-duel default to *different model families*. xreview detects
known harness environments and refuses detected self-review unless the user
explicitly overrides that guard.

**A prompt decides what the model wants to do; a hook decides what
actually happens.** The Stop hook is that idea. A rule in a skill file
is an intention; the gate lives in the harness.

---

## Known limits

- **Platform**: the `bin/` scripts are `#!/usr/bin/env zsh` and use
  zsh-only parameter expansion, so Linux needs zsh installed and native
  Windows cannot run them — on Windows, run the agent inside WSL and
  `apt install zsh`. They also need `perl` and `python3` on PATH (present
  by default on macOS and most Linux). The Python hook runs natively
  anywhere `env` can find a `python3`.
- **ai-duel's neutral third-party judge is off by default.** It is
  Claude against Codex unless you set `AI_DUEL_NEUTRAL` and have the
  corresponding CLI on PATH. Auto-detection was deliberately removed:
  which provider receives the full text of your question should be a
  decision you made on purpose.
- **Quota**: a multi-round xreview is expensive. Reserve it for plans
  that will actually be implemented, not one-line changes.
- **Identity detection**: author-family detection comes from harness
  environment variables. A plain terminal cannot prove who authored the work
  and therefore fails open; set `XREVIEW_AUTHOR` and `XREVIEW_REVIEWER`
  deliberately there. `XREVIEW_AUTHOR` also corrects multiplexer environments
  that inherit the wrong harness variable.
- **Audit, not access control**: anyone who can edit the target can forge a
  marker and digest. Use repository permissions and review logs for adversarial
  protection.
- **Codex does not follow a file-level symlink of `SKILL.md`.** If a
  skill silently disappears from Codex, check that
  `~/.codex/skills/<name>/SKILL.md` is a real file (a directory symlink
  whose target contains a real `SKILL.md` is fine). `./install.sh`
  copies real files.

---

## License

MIT. See [LICENSE](LICENSE).

This independent project is not affiliated with or endorsed by Anthropic,
OpenAI, xAI, or the similarly named repositories in the
[landscape](docs/landscape.md).
