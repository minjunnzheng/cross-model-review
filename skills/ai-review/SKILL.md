---
name: ai-review
description: "Anti-flattery manuscript review — a piece of writing goes through anonymisation plus a multi-lens review: four lenses in parallel under an absolute ban on praise, a rebuttal round that filters out criticism invented to look thorough, then an editor pass that produces a revised draft. Triggers on \"ai-review\", \"review this draft\", \"poke holes in this\", \"what's wrong with this piece\", \"don't just tell me it's good\", \"be honest about this\", \"tear this apart\". NOT for plans and design proposals (use xreview), choosing between two options (use ai-duel), code review, or fact checking."
---

# ai-review — anti-flattery manuscript review

**This is for writing meant to be read by people — not a plan, not code.** A
proposal goes to xreview, where the output is an implementable consensus. Here
the output is a draft that has actually been picked apart.

Tool: `ai-review` (must be on PATH; see the package README).

## Usage

```
ai-review draft.md          # full: 4 lenses in parallel + rebuttal filter + revised draft
ai-review -q draft.md       # quick: single reviewer, one pass, about a minute
ai-review - < draft.md      # read from stdin
```

## Why it is shaped this way (do not optimise these away)

1. **The author is anonymised.** The moment a model knows the user wrote it, it
   starts cushioning, and criticism drops a whole grade in strength. Removing the
   flattery trigger is the precondition for any of this working — do not "give it
   more context" by putting the authorship back in.
2. **Four lenses in parallel, each with a fixed itemised format.** The structured
   rubric is what lets a mid-tier model hold the behaviour without relying on a
   frontier model's judgement. The lenses are **argument and structure**
   (evidence, leaps in reasoning, self-contradiction), **content and fact**
   (factual errors, claims needing a citation, units), **language and expression**
   (padding, inconsistent terminology, sentences carrying no information), and
   **the reader's view** (where they get lost, where they lose patience, whether
   they end up convinced). None of them sees what the others wrote.
3. **The rebuttal round is not a courtesy.** A hard review squeezes out a batch of
   criticism invented to look useful; the rebuttal round exists to filter exactly
   that, marking each finding upheld / overstated / rejected. Without it the
   revised draft chases noise and gets worse.

Output language follows `AI_LANG` (or `AI_REVIEW_LANG`), English by default.
Quotes from the original keep the language they were written in.

## Reporting back

Lead with the tally: how many findings, how many upheld, how many overstated or
rejected. Then list **only the upheld ones**, one per line. Do not paste all four
lenses' raw output.

The revised draft and every round's raw output land in `.ai-review/<timestamp>/`
under the current directory; the script prints the path.

**Do not write the revised draft back over the original.** The user reads the
upheld findings first and decides which to take — which criticism to accept is
the author's call, not this tool's.
