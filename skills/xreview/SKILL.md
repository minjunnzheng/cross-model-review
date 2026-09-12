---
name: xreview
description: "Cross-model review of a plan, proposal or script in one persistent reviewer session until consensus. Use for an explicit cross-model review request, a major architecture or scientific-method decision before implementation, an expensive computation before launch, or AI-generated content before it enters a trusted reference library, notes or knowledge base. Routine edits, local implementation choices, factual lookups and ordinary comparisons do not trigger this workflow. Use ai-duel for independent alternatives to an unresolved major decision."
---

# xreview — cross-model review loop

**You are the author, another model family is the reviewer.** The same head checking its own work always has blind spots; only a different model family, looking at it from the outside, catches them.

Tool: `xreview` (must be on PATH; see the package README). It handles every reviewer call — **do not assemble codex/grok/claude commands yourself**.

## When to use this workflow

Start a review when the user explicitly requests cross-model review, or before one of these consequential actions:

- Implementing a major architecture or scientific-method decision whose mistakes would cause substantial downstream rework or invalidate results.
- Launching an expensive computation.
- Writing AI-generated claims, citations or data into a trusted reference library, notes or knowledge base.

An ordinary bug fix, bounded refactor, configuration or skill edit, or local implementation choice does not qualify merely because it takes several steps or has multiple reasonable solutions. Handle those tasks directly with checks appropriate to the change. Apply any explicit review requirement in the user's instructions or project rules.

For an unresolved major choice, use ai-duel to compare independent alternatives. For an existing proposal that needs revision and agreement, use xreview. Do not chain both workflows automatically for the same decision; review new consequential changes if they arise. Source verification remains separate: use bibcheck for bibliographic records and check claims and values against their original sources.

Once review is in scope and authorized, carry out the required work without asking the user to reapprove routine steps. Ask only when a material decision, missing information or execution permission is required.

## Choose an operation

- **Start, resume, resolve findings, or stamp a review:** read [review loop](references/review-loop.md). When starting, also read [reviewer selection](references/reviewers.md); the reviewer must be from a different family. Reuse the existing session for subsequent rounds.
- **Inspect status:** run `xreview status --session <known-directory>`. Read [command reference](references/commands.md) only for logs, checks or configuration options. A status request does not start a review.
- **An actual xreview-guard block or guard configuration request:** read [guard behavior](references/guard.md). Do not disable or bypass it to complete an unrelated task.
- **Visual review:** the review loop requires screenshots of the relevant rendered states before requesting a verdict.

Use `/Users/br/bin/xpane <label> xreview ...` for CLI calls. Review working files belong in the session scratchpad when project rules exclude temporary files from the repo. Use explicit session directories throughout.

## Why it is shaped this way (do not optimise these away)

1. **The same reviewer thread throughout.** A reviewer that cold-starts every round keeps inventing new small defects, so you never finish fixing -> over-engineering. The same thread remembers what it said last round: round 1 finds the real problems, later rounds sign off on your fixes, and that is what converges. `xreview round` resumes that same thread — do not bypass it.
2. **No round limit.** A limit forces the worst outcome: on the last round the reviewer pretends there is nothing wrong just to end it. There is exactly one pass criterion — **consensus**.
3. **The marker is the handshake.** Only a PASS can be stamped; `xreview stamp` refuses every non-PASS verdict and has no force override. The marker is bound to the exact reviewed snapshot, so editing the target after PASS requires another round.

## How to report to the user

Summarize each round without pasting the full transcript. One line per round:

```
Round N: X findings -> Y fixed, Z pushed back, W unresolved
```

At the end report: total rounds, which substantive things actually changed (<=5 items), and where it was stamped. Only use `xreview log` when the user wants the details.

## Cost

Use the token usage reported by the actual CLI run. Cost and elapsed time depend on the model, reviewed material, caching and number of rounds; do not quote a fixed per-round estimate. Keep the review material focused on the consequential decision.

## Division of labour with the sibling tools

- **xreview** (this tool) = iterate to consensus; the subject is "a plan or script that will be implemented", the product is a stamped final version.
- **`ai-duel`** = one-shot; both sides answer independently, peer-critique, then a blind verdict; the subject is "an open question", the product is "which option is better".
- **`ai-review`** = anti-flattery review of a piece of writing (multiple lenses + rebuttal round); the subject is "an article written for humans".
- Bibliography verification is out of scope. Do not treat an xreview PASS as a DOI check.
