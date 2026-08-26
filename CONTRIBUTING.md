# Contributing

## Local checks

Requirements for deterministic development checks are zsh, Python 3, Perl, Git, and standard Unix tools. No model account or network call is needed for the smoke suite:

```bash
zsh tests/smoke.zsh
claude plugin validate .
git diff --check
```

The smoke suite uses a fake `claude` reviewer CLI (`tests/fixtures/claude`, driven by `FAKE_REVIEW_MODE`) and an isolated temporary `HOME`. It prints the scratch directory and leaves it for inspection. There is no fake `codex` or `grok` yet, so the non-claude reviewer paths are exercised only by real use.

## Change rules

- Keep Claude Code plugin metadata in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` at the same version.
- Preserve strict verdict sentinels: only the final non-blank `VERDICT: PASS` or `VERDICT: CHANGES-REQUESTED` line is machine-readable.
- Update both `xreview check` and `hooks/xreview-guard.py` when marker serialization changes, then add a parity test.
- Do not add a provider or transmit content merely because a CLI or API key is present. External providers must remain explicit opt-ins.
- Add tests for failure paths, especially quota errors, empty output, stale markers, installer conflicts, and concurrent sessions.

Open a pull request with the behaviour change, its test, and any README or changelog update. Avoid including model transcripts or machine-specific paths in commits.
