# Public release checklist

Remote publication is intentionally separate from local implementation. Run these steps only after the release changes are committed.

1. Fetch every remote ref that GitHub exposes, including pull-request heads when they exist:

   ```bash
   git fetch --prune origin
   git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'
   ```

2. Verify the immutable candidate commit, not the working tree:

   ```bash
   scripts/release-audit.zsh HEAD
   ```

   Record the exact SHA printed by the script. The audit exports that commit with `git archive`, runs the smoke suite and official Claude plugin validator against the export, then scans all locally reachable refs and commit messages for high-signal credentials and personal paths.

3. If any credential or private content ever existed in the remote, revoke the credential first and publish from a newly created clean repository. Local tools cannot prove that unreachable objects are absent from an existing GitHub object database. If the remote has always been clean, record that residual limitation before converting it.

4. Push while the repository is still private, then verify that the remote branch resolves to the audited SHA. Create the release tag at that same SHA; do not rebuild or edit between audit and tag.

5. Set GitHub metadata. Suggested description: `Tamper-evident cross-model review gates for plans, decisions, and manuscripts.` Suggested topics: `ai-review`, `claude-code`, `codex`, `cross-model`, `agent-skills`, `developer-tools`.

6. Change repository visibility to public last. From a logged-out browser, verify the README, license, CI status, clone URL, and marketplace installation commands.

7. Optional: submit the Claude Code plugin through Anthropic's official plugin submission form after the public install path has been tested.
