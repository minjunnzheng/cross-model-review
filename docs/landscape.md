# Cross-model review tool landscape

Last checked: 2026-08-27.

This is a scope map, not a ranking. These projects overlap in name or method but make different workflow choices.

| Project | Primary scope | Workflow shape | Difference from this repository |
|---|---|---|---|
| [promptadvisers/claudex](https://github.com/promptadvisers/claudex) | Claude Code plan and diff review | Claude and Codex loop through fixed reviewer personas; includes doctor/status commands | This repository keeps one reviewer thread until consensus and also ships separate decision-duel and manuscript-review workflows |
| [formin/multi-model-review](https://github.com/formin/multi-model-review) | Spec-driven development | Builds portable review packages for Claude, Codex, Gemini, local OSS models, and other CLIs | This repository operates directly on a target file and records PASS/SKIP gates rather than producing spec handoff packages |
| [andreidavid/codex-review](https://github.com/andreidavid/codex-review) | Post-commit code review in Claude Code | Codex findings can block and trigger fix/amend loops; supports waivers | This repository's `xreview` targets plans/proposals before implementation and does not amend commits |
| [DheerG/codex-review-loop](https://github.com/DheerG/codex-review-loop) | Review-until-clean across agent harnesses | Isolated read-only Codex review adapters for Claude Code, Codex, OpenCode, and Gemini CLI | This repository is a smaller zsh/Python toolkit centred on a persistent cross-family reviewer thread |
| [spsk-dev/code-review](https://github.com/spsk-dev/code-review) | Pull-request review | Parallel Claude, Codex, and Gemini reviewers with confidence scoring | This repository does not aggregate PR findings or assign confidence scores |
| [24kchengYe/cross-model-review](https://github.com/24kchengYe/cross-model-review) | Claude Code skill routing through OpenRouter | Sends content to selectable GPT, DeepSeek, Gemini, GLM, Qwen, Llama, and Mistral models | It is a separate project with the same repository name. This repository uses locally installed model CLIs and provides three distinct review gates |
| [MacWulf/claude-in-codex](https://github.com/MacWulf/claude-in-codex) | Claude review and task transfer from Codex | Read-only review, adversarial review, rescue, background status, and transcript transfer | This repository is bidirectional across supported author families and focuses on auditable review artifacts rather than task transfer |

The human-facing name **Cross-model Review Gates** distinguishes this project without changing the existing `cross-model-review` repository and plugin identifier.

This project is independent and is not affiliated with, endorsed by, or maintained by the projects listed above, Anthropic, OpenAI, or xAI.
