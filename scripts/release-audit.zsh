#!/usr/bin/env zsh
# Verify an immutable candidate commit, not the maintainer's working tree.
set -euo pipefail

ROOT="${0:A:h:h}"
REV="${1:-}"
[[ -n "$REV" ]] || { print -u2 "Usage: scripts/release-audit.zsh <commit-or-tag>"; exit 1; }

[[ -z "$(git -C "$ROOT" status --porcelain)" ]] \
  || { print -u2 "Working tree is not clean. Commit first, then audit that commit."; exit 1; }

SHA="$(git -C "$ROOT" rev-parse --verify "$REV^{commit}")"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/cross-model-review-release.XXXXXX")"
EXPORT="$SCRATCH/export"
mkdir -p "$EXPORT"
git -C "$ROOT" archive "$SHA" | tar -xf - -C "$EXPORT"

print "candidate: $SHA"
print "archive:   $EXPORT"

zsh "$EXPORT/tests/smoke.zsh"
command -v claude > /dev/null 2>&1 \
  || { print -u2 "Claude CLI is required for official plugin validation."; exit 1; }
claude plugin validate "$EXPORT"

# Conservative high-signal patterns. This supplements, rather than replaces, provider-side
# secret scanning. Scan every locally available ref; RELEASE.md explains how to fetch PR refs.
SECRET_PATTERN='(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----|/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/)'
# README's Stop-hook snippet deliberately shows /Users/you/… as the home-directory
# placeholder; it is documentation, not a leaked path. Filter exactly that.
PLACEHOLDER='/Users/you/'
FOUND=0
for commit in ${(f)"$(git -C "$ROOT" rev-list --all)"}; do
  if git -C "$ROOT" grep -I -nE "$SECRET_PATTERN" "$commit" -- . | grep -vF "$PLACEHOLDER" | grep ''; then
    FOUND=1
  fi
done
if git -C "$ROOT" log --all --format='%H %s%n%b' | grep -nE "$SECRET_PATTERN" | grep -vF "$PLACEHOLDER" | grep ''; then
  FOUND=1
fi
(( FOUND == 0 )) || { print -u2 "Potential secret or personal path found in reachable history."; exit 1; }

git -C "$ROOT" diff-tree --check --root "$SHA"
print "PASS: release candidate $SHA"
print "Scratch artifacts retained at: $SCRATCH"
