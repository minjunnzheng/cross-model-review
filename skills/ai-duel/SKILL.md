---
name: ai-duel
description: One-shot cross-model verdict — the same open question goes to Claude and to Codex, each answering cold, then one peer-critique round, then a double-blind claim-level verdict on which answer holds up. Triggers on "ai-duel", "get a second opinion", "ask another model", "what would a different model say", "settle this for me", "which approach is better" — or any design choice with no textbook answer where both paths are defensible. NOT for iterating to consensus (use xreview), fact and literature lookup, poking holes in a piece of writing (use ai-review), or a coding task where two models would edit the same file (isolate them in two git worktrees instead).
---

# ai-duel — one-shot cross-model verdict

**What comes out is "which answer holds up", not "a fixed answer".** If you need
to iterate toward consensus, use xreview. This tool is one-shot: three rounds and
it is over.

Tool: `ai-duel` (must be on PATH; see the package README). It handles every claude and
codex invocation — **do not assemble those commands yourself.**

## Usage

```
ai-duel "the full question"     # full three rounds: independent answers → critique → blind verdict
ai-duel -c "follow-up"          # carry the previous duel's conclusion in as background
ai-duel -q claude "follow-up"   # quick: ask one model, take its answer, skip critique and verdict
```

**The question must carry its own context.** Both models start cold and cannot
see this conversation. Put the proposal text, the constraints and the criteria
into the question itself. Writing "the approach above" or "what we just
discussed" sends out a question with no subject, and what comes back is two
models each answering something they imagined.

## Why it is shaped this way (do not optimise these away)

1. **Both sides answer cold, and only then critique each other.** Letting either
   one see the other's answer first anchors it, and the second answer degrades
   into a commentary on the first. Independence is the only thing this tool sells.
2. **Round 3 is a double-blind claim-level verdict**, not "which do you prefer".
   Claims are compared one by one, without knowing who wrote which, so it cannot
   collapse into mutual flattery or into whoever wrote more confidently.
3. **The third-party neutral judge is off by default.** Adding Grok or
   Antigravity requires setting `AI_DUEL_NEUTRAL=auto` (or `grok` / `agy` /
   `grok,agy`). It deliberately does not auto-enable on PATH detection: which
   provider receives the full text of the question has to be a decision the user
   stated out loud, not something that happens silently because a CLI happens to
   be installed.

Output language follows `AI_LANG` (or `AI_DUEL_LANG`), English by default.

## Reporting back

One line per round, no full transcripts. Finish with the verdict, where the two
sides genuinely disagreed, and which claims the verdict turned on. Working files
land in `.ai-duel/<timestamp>/` under the current directory; the script prints the
path, so point the user there if they want detail.

The verdict is not scripture. If you read it and think it is wrong, say so and
give your reason — do not accept it just because two models signed off on it.
