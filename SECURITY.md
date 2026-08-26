# Security policy

## Reporting a vulnerability

Use GitHub's private vulnerability-reporting form when it is enabled for this repository. If it is unavailable, open an issue that asks the maintainer for a private contact channel; do not include exploit details, credentials, private prompts, or local file contents in a public issue.

Do not test a report against systems, accounts, or model quotas you do not own.

## Security boundary

These tools invoke model CLIs already installed and authenticated on the user's machine. Prompts, referenced files, reviewer output, and optional project context can be transmitted to the provider selected by that CLI. `AI_DUEL_NEUTRAL` can additionally send a transcript to xAI or another configured neutral provider. Review the data-flow section in [README.md](README.md) before using private material.

`XREVIEW-PASS` is a tamper-evident audit record: it binds the marker to the exact reviewed snapshot and detects later edits. It is not a signature and does not prevent a user or agent with write access from forging text and a digest. `XREVIEW-SKIP` is an explicit human exemption, not proof that review occurred.

The Stop hook fails open on malformed hook infrastructure input or an internal exception so it cannot permanently trap a Claude Code session. Once a transcript identifies a matched target, a missing, unreadable, unstamped, or stale target fails closed.

## Supported code

Security fixes target the latest release and the current `main` branch. Older snapshots may not receive fixes.
