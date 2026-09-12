## Picking the reviewer

Default is Codex; the tool refuses to let the author's own family review (`✗ The author is claude, so claude cannot be the reviewer`), so you never need to work out who is running.

| Reviewer | How | When |
|---|---|---|
| Codex (default) | nothing to set | the standing choice — strongest at code, config and plan mechanics |
| Claude | automatic when the author is Codex; or `--reviewer claude` | Codex is the author, or Codex is out of quota |
| Grok 4.6 | `xreview start --reviewer grok …` | user asks for Grok; a second opinion after a Codex PASS you distrust; Codex is out of quota |

Pick the engine once, at `start`, as `--reviewer ENGINE[:MODEL]` — e.g. `--reviewer grok:grok-4.6`, `--reviewer claude:opus` (`XREVIEW_REVIEWER` works too; the flag wins). Engine and model are pinned into the session, so `round` and `stamp` need nothing set. Model precedence: `-m`, then `:MODEL`, then the per-engine `XREVIEW_*_MODEL` variables.
