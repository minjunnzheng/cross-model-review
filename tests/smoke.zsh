#!/usr/bin/env zsh
set -euo pipefail
setopt NO_BG_NICE

ROOT="${0:A:h:h}"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/cross-model-review-tests.XXXXXX")"
FAKEBIN="$ROOT/tests/fixtures"

fail() { print -u2 "FAIL: $*"; exit 1; }
pass() { print "ok: $*"; }
assert_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_dir() { [[ -d "$1" ]] || fail "missing directory: $1"; }
assert_contains() { grep -q -- "$2" "$1" || fail "$1 does not contain: $2"; }
expect_fail() {
  if "$@"; then
    fail "command unexpectedly succeeded: $*"
  fi
}

print "scratch: $SCRATCH"

# Static structure and syntax.
zsh -n "$ROOT"/bin/xreview "$ROOT"/bin/ai-duel "$ROOT"/bin/ai-review "$ROOT/install.sh"
python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())' "$ROOT/hooks/xreview-guard.py"
for json in "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json" "$ROOT/hooks/hooks.json"; do
  python3 -m json.tool "$json" > /dev/null
done
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
plugin = json.loads((root / ".claude-plugin/plugin.json").read_text())
market = json.loads((root / ".claude-plugin/marketplace.json").read_text())
assert plugin["version"] == market["plugins"][0]["version"]
assert plugin["name"] == market["plugins"][0]["name"]
PY
pass "syntax, JSON, and manifest agreement"

# CLI help: complete (the sed line range in usage() is easy to knock off by one) and
# consistent — every tool answers -h/--help without touching a model CLI.
HELP="$("$ROOT/bin/xreview" 2>&1 || true)"
print -r -- "$HELP" | head -1 | grep -q 'xreview — cross-model review loop' || fail "xreview usage lost its first line"
print -r -- "$HELP" | grep -q 'XREVIEW_ALLOW_SELF' || fail "xreview usage truncates the env-var list"
"$ROOT/bin/ai-duel" -h > /dev/null 2>&1 || fail "ai-duel -h does not exit 0"
"$ROOT/bin/ai-duel" --help > /dev/null 2>&1 || fail "ai-duel --help does not exit 0"
"$ROOT/bin/ai-review" -h > /dev/null 2>&1 || fail "ai-review -h does not exit 0"
"$ROOT/bin/ai-review" --help > /dev/null 2>&1 || fail "ai-review --help does not exit 0"
pass "usage output is complete and -h/--help works everywhere"

# Installer: clean install, identical reinstall, all-destination preflight, and backed-up replace.
TEST_HOME="$SCRATCH/home"
mkdir -p "$TEST_HOME"
HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" "$ROOT/install.sh" --hooks > "$SCRATCH/install-clean.out"
assert_file "$TEST_HOME/bin/xreview"
assert_file "$TEST_HOME/.claude/hooks/xreview-guard.py"
assert_dir "$TEST_HOME/.codex/skills/xreview"
HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" "$ROOT/install.sh" --hooks > "$SCRATCH/install-identical.out"
assert_contains "$SCRATCH/install-identical.out" "unchanged"
print -r -- '# local conflicting edit' >> "$TEST_HOME/bin/xreview"
mv "$TEST_HOME/.agents/skills/ai-duel" "$SCRATCH/held-ai-duel"
cp "$TEST_HOME/bin/xreview" "$SCRATCH/conflicting-xreview"
expect_fail env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" "$ROOT/install.sh" --hooks
[[ ! -e "$TEST_HOME/.agents/skills/ai-duel" ]] || fail "installer made a partial change before conflict exit"
cmp -s "$TEST_HOME/bin/xreview" "$SCRATCH/conflicting-xreview" || fail "conflict changed without --replace"
HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" "$ROOT/install.sh" --hooks --replace > "$SCRATCH/install-replace.out"
cmp -s "$TEST_HOME/bin/xreview" "$ROOT/bin/xreview" || fail "--replace did not install exact CLI"
assert_dir "$TEST_HOME/.agents/skills/ai-duel"
assert_contains "$SCRATCH/install-replace.out" "backup root"
pass "non-destructive installer"

run_start() {
  local project="$1" mode="$2" label="$3"
  shift 3
  (
    cd "$project"
    env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex XREVIEW_REVIEWER=claude \
      FAKE_REVIEW_MODE="$mode" "$@" "$ROOT/bin/xreview" start --label "$label" PLAN.md
  )
}

only_session() {
  local project="$1" dirs
  dirs=("$project"/.xreview/*(/N))
  (( ${#dirs} == 1 )) || fail "expected one session under $project, got ${#dirs}"
  print -r -- "${dirs[1]}"
}

# PASS is bound to the exact reviewed snapshot, including no-final-newline inputs.
PASS_PROJECT="$SCRATCH/pass"
mkdir -p "$PASS_PROJECT"
print -n -- 'review me without a final newline' > "$PASS_PROJECT/PLAN.md"
run_start "$PASS_PROJECT" pass pass > "$SCRATCH/pass.out" 2> "$SCRATCH/pass.err"
PASS_SESSION="$(only_session "$PASS_PROJECT")"
expect_fail "$ROOT/bin/xreview" stamp
"$ROOT/bin/xreview" stamp --session "$PASS_SESSION"
"$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md"
pass "snapshot-bound PASS stamps and immediately checks"

# A second review/stamp includes the earlier marker in the new reviewed snapshot.
(
  cd "$PASS_PROJECT"
  env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex XREVIEW_REVIEWER=claude \
    FAKE_REVIEW_MODE=pass "$ROOT/bin/xreview" start --label second PLAN.md > /dev/null 2> /dev/null
)
PASS_SESSIONS=("$PASS_PROJECT"/.xreview/*(/N))
(( ${#PASS_SESSIONS} == 2 )) || fail "second review did not create a distinct run"
SECOND_SESSION="${PASS_SESSIONS[-1]}"
"$ROOT/bin/xreview" stamp --session "$SECOND_SESSION"
"$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md"
VALID_PASS="$SCRATCH/valid-pass.md"
cp "$PASS_PROJECT/PLAN.md" "$VALID_PASS"
pass "second stamp remains valid"

# Editing either before or after the final marker invalidates PASS, and check says why.
perl -0pi -e 's/review me/changed/' "$PASS_PROJECT/PLAN.md"
expect_fail "$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md"
"$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md" 2> "$SCRATCH/check-stale.err" || true
assert_contains "$SCRATCH/check-stale.err" "sha256 mismatch"
print -r -- 'content after marker' >> "$PASS_PROJECT/PLAN.md"
expect_fail "$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md"
"$ROOT/bin/xreview" check "$PASS_PROJECT/PLAN.md" 2> "$SCRATCH/check-nomark.err" || true
assert_contains "$SCRATCH/check-nomark.err" "no XREVIEW-PASS or XREVIEW-SKIP marker"
pass "stale PASS is rejected with a diagnostic"

# A PASS verdict cannot stamp bytes changed after the reviewed snapshot.
DRIFT_PROJECT="$SCRATCH/drift"
mkdir -p "$DRIFT_PROJECT"
print -r -- 'reviewed bytes' > "$DRIFT_PROJECT/PLAN.md"
run_start "$DRIFT_PROJECT" pass drift > /dev/null 2> /dev/null
DRIFT_SESSION="$(only_session "$DRIFT_PROJECT")"
print -r -- 'changed after review' >> "$DRIFT_PROJECT/PLAN.md"
expect_fail "$ROOT/bin/xreview" stamp --session "$DRIFT_SESSION"
pass "stamp rejects post-review changes"

# Body decoys do not override the exact final sentinel.
CHANGES_PROJECT="$SCRATCH/changes"
mkdir -p "$CHANGES_PROJECT"
print -r -- 'needs review' > "$CHANGES_PROJECT/PLAN.md"
run_start "$CHANGES_PROJECT" changes changes > /dev/null 2> /dev/null
CHANGES_SESSION="$(only_session "$CHANGES_PROJECT")"
[[ "$(grep '^verdict=' "$CHANGES_SESSION/meta")" == 'verdict=CHANGES' ]] || fail "decoy PASS was accepted"
expect_fail "$ROOT/bin/xreview" stamp --session "$CHANGES_SESSION"
pass "strict verdict parsing"

# --reviewer flag: picks and pins the engine without XREVIEW_REVIEWER, and rejects
# names outside the engine registry before any session state is created.
FLAG_PROJECT="$SCRATCH/flag"
mkdir -p "$FLAG_PROJECT"
print -r -- 'flag plan' > "$FLAG_PROJECT/PLAN.md"
(
  cd "$FLAG_PROJECT"
  env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex FAKE_REVIEW_MODE=pass \
    "$ROOT/bin/xreview" start --label flag --reviewer claude:spec-model PLAN.md > /dev/null 2> /dev/null
)
FLAG_SESSION="$(only_session "$FLAG_PROJECT")"
grep -qx 'reviewer=claude' "$FLAG_SESSION/meta" || fail "--reviewer did not pin the engine into the session"
grep -qx 'model=spec-model' "$FLAG_SESSION/meta" || fail "--reviewer ENGINE:MODEL did not pin the model"
expect_fail env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex \
  "$ROOT/bin/xreview" start --reviewer gemini "$FLAG_PROJECT/PLAN.md" 2> /dev/null
pass "--reviewer flag selects and validates the engine"

# Missing sentinel and non-zero reviewer exit are hard failures with diagnostics.
for mode in no-verdict fail; do
  project="$SCRATCH/backend-$mode"
  mkdir -p "$project"
  print -r -- 'backend failure fixture' > "$project/PLAN.md"
  if run_start "$project" "$mode" "$mode" > "$project/out" 2> "$project/err"; then
    fail "$mode reviewer fixture unexpectedly succeeded"
  fi
  assert_contains "$project/err" "last 20 lines"
  session="$(only_session "$project")"
  [[ "$(grep '^state=' "$session/meta")" == 'state=failed' ]] || fail "$mode run not marked failed"
  [[ ! -e "$project/.xreview/current" ]] || fail "failed run installed a shared current pointer"
done
pass "backend failures are diagnostic and non-zero"

# Two same-label starts in one cwd create separate runs; explicit sessions never cross.
CONCURRENT="$SCRATCH/concurrent"
mkdir -p "$CONCURRENT"
print -r -- 'plan A' > "$CONCURRENT/PLAN.md"
(
  cd "$CONCURRENT"
  env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex XREVIEW_REVIEWER=claude \
    FAKE_REVIEW_MODE=pass FAKE_REVIEW_DELAY=0.2 "$ROOT/bin/xreview" start --label same PLAN.md > "$SCRATCH/a.out" 2> "$SCRATCH/a.err"
) &
pid_a=$!
(
  cd "$CONCURRENT"
  env PATH="$FAKEBIN:$PATH" XREVIEW_AUTHOR=codex XREVIEW_REVIEWER=claude \
    FAKE_REVIEW_MODE=pass FAKE_REVIEW_DELAY=0.2 "$ROOT/bin/xreview" start --label same PLAN.md > "$SCRATCH/b.out" 2> "$SCRATCH/b.err"
) &
pid_b=$!
wait "$pid_a"
wait "$pid_b"
CONCURRENT_SESSIONS=("$CONCURRENT"/.xreview/*(/N))
(( ${#CONCURRENT_SESSIONS} == 2 )) || fail "concurrent runs collided"
for session in "${CONCURRENT_SESSIONS[@]}"; do
  XREVIEW_SESSION="$session" "$ROOT/bin/xreview" status > /dev/null
done
[[ ! -e "$CONCURRENT/.xreview/current" ]] || fail "shared current pointer still exists"
pass "atomic run creation and explicit-session isolation"

# SKIP is a final-line human exemption, not a digest-bearing PASS.
SKIP_FILE="$SCRATCH/SKIP-PLAN.md"
print -r -- 'not reviewed' > "$SKIP_FILE"
print -r -- 'XREVIEW-SKIP user explicitly exempted this file' >> "$SKIP_FILE"
"$ROOT/bin/xreview" check "$SKIP_FILE"
print -r -- 'later content' >> "$SKIP_FILE"
expect_fail "$ROOT/bin/xreview" check "$SKIP_FILE"
pass "explicit SKIP semantics"

# Stop hook: opt-in scope, valid/invalid markers, missing targets, and infrastructure fail-open.
HOOK_PROJECT="$SCRATCH/hook"
mkdir -p "$HOOK_PROJECT"
HOOK_PLAN="$HOOK_PROJECT/PLAN.md"
print -r -- 'hook plan' > "$HOOK_PLAN"
TRANSCRIPT="$HOOK_PROJECT/transcript.jsonl"
print -r -- "{\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"$HOOK_PLAN\"}}]}}" > "$TRANSCRIPT"
hook_input() {
  print -r -- "{\"cwd\":\"$HOOK_PROJECT\",\"transcript_path\":\"$TRANSCRIPT\"}" \
    | python3 "$ROOT/hooks/xreview-guard.py"
}
[[ -z "$(hook_input)" ]] || fail "hook blocked without opt-in guard"
touch "$HOOK_PROJECT/.xreview-guard"
HOOK_OUT="$(hook_input)"
[[ "$HOOK_OUT" == *'"decision": "block"'* ]] || fail "hook did not block unmarked plan"
print -r -- 'XREVIEW-SKIP explicit fixture exemption' >> "$HOOK_PLAN"
[[ -z "$(hook_input)" ]] || fail "hook rejected final-line SKIP"

cp "$VALID_PASS" "$HOOK_PLAN"
[[ -z "$(hook_input)" ]] || fail "hook rejected a hash-valid PASS"
perl -0pi -e 's/review me/hook changed/' "$HOOK_PLAN"
[[ "$(hook_input)" == *'"decision": "block"'* ]] || fail "hook accepted stale PASS"
UNREADABLE_PLAN="$HOOK_PROJECT/PLAN-unreadable.md"
print -r -- 'unreadable fixture' > "$UNREADABLE_PLAN"
chmod 000 "$UNREADABLE_PLAN"
print -r -- "{\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"$UNREADABLE_PLAN\"}}]}}" > "$TRANSCRIPT"
[[ "$(hook_input)" == *'"decision": "block"'* ]] || fail "hook failed open for a matched unreadable target"
MISSING_PLAN="$HOOK_PROJECT/PLAN-missing.md"
print -r -- "{\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"$MISSING_PLAN\"}}]}}" > "$TRANSCRIPT"
[[ "$(hook_input)" == *'"decision": "block"'* ]] || fail "hook failed open for a matched missing target"
[[ -z "$(print -r -- 'not-json' | python3 "$ROOT/hooks/xreview-guard.py")" ]] || fail "malformed hook input did not fail open"
pass "Stop hook marker and failure semantics"

print "PASS: all smoke tests"
