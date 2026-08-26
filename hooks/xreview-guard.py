#!/usr/bin/env python3
# xreview-guard — Stop hook guard: no marker at the end of the plan file, no finishing up.
#
# This is the "gatekeeper" half of the cross-model review loop (the other half is the
# /xreview skill, which supplies the review methodology). The two halves are deliberately
# decoupled and are joined only by one password: the marker.
#   The guard knows nothing but the marker — sees it, lets you through; does not see it,
#   blocks. It performs no review of its own.
#   Wrong blocking behaviour -> fix this script; poor review quality -> fix the skill.
#
# Why have a guard at all: human discipline is unreliable. The small plans that look easy
# are the ones you let yourself off with, and those are exactly the ones that blow up.
# Rather than having to remember every time, make it happen automatically every time.
#
# ── Scope (opt-in; does nothing at all by default) ───────────────
# The guard only activates when a `.xreview-guard` file exists in the cwd or one of its
# ancestor directories. So a pure writing directory is never affected, unless you put that
# file there yourself.
#
# The contents of `.xreview-guard` = one glob per line, naming the files that count as "plans":
#     # comments and blank lines are ignored
#     PLAN*.md
#     docs/plans/*.md
#     *proposal*.md
# An empty file (`touch .xreview-guard`) = use the built-in default globs (see DEFAULT_GLOBS).
# A file whose only line is `off` = temporarily disable the guard for that directory.
#
# ── Pass conditions ──────────────────────────────────────────────
# XREVIEW-PASS is the final line and carries a SHA-256 digest of the exact reviewed bytes.
# XREVIEW-SKIP is a final-line, explicit human exemption rather than a review result.
# Same rule as `xreview check`.
#
# ── Global off switch ────────────────────────────────────────────
# export XREVIEW_GUARD=0
#
# Any error fails open (exit 0, let it through) — a broken guard must never leave you unable
# to finish up.
import fnmatch
import hashlib
import json
import os
import re
import sys

DEFAULT_GLOBS = [
    "PLAN*.md", "plan*.md", "*_PLAN.md", "*-plan.md",
    "*計劃*.md", "*計畫*.md", "*方案*.md", "*提案*.md",
]
EDIT_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
def allow():
    sys.exit(0)


def find_guard_file(cwd):
    d = os.path.abspath(cwd)
    while True:
        p = os.path.join(d, ".xreview-guard")
        if os.path.isfile(p):
            return p
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def read_globs(guard_path):
    globs, off = [], False
    with open(guard_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if s.lower() == "off":
                off = True
            else:
                globs.append(s)
    return (globs or DEFAULT_GLOBS), off


def edited_files(transcript_path):
    """Files touched with Write/Edit in this session (including ones written by subagents)."""
    out = []
    with open(transcript_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or "tool_use" not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            content = (rec.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict) or item.get("type") != "tool_use":
                    continue
                if item.get("name") not in EDIT_TOOLS:
                    continue
                fp = (item.get("input") or {}).get("file_path") or \
                     (item.get("input") or {}).get("notebook_path")
                if fp and fp not in out:
                    out.append(fp)
    return out


def has_marker(path):
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except OSError:
        return False
    lines = raw.splitlines(keepends=True)
    if not lines:
        return False
    last = lines[-1].rstrip(b"\r\n").decode("utf-8", "replace")
    if re.match(r"^(?:<!--\s*|//\s*|#\s*|!\s*)?XREVIEW-SKIP\b", last):
        return True
    if not re.match(r"^(?:<!--\s*|//\s*|#\s*|!\s*)?XREVIEW-PASS\b", last):
        return False
    digest = re.search(r"\bsha256=([0-9a-f]{64})\b", last)
    sep = re.search(r"\bsep=([01])\b", last)
    if not digest or not sep:
        return False
    prefix = b"".join(lines[:-1])
    if sep.group(1) == "1":
        if not prefix.endswith(b"\n"):
            return False
        prefix = prefix[:-1]
    return hashlib.sha256(prefix).hexdigest() == digest.group(1)


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except Exception:
        allow()

    # 1. Infinite-loop protection: if the guard is already blocking, never block a second time
    if data.get("stop_hook_active"):
        allow()
    # 2. A subagent finishing up is none of our business
    if data.get("agent_id"):
        allow()
    # 3. Global switch
    if os.environ.get("XREVIEW_GUARD") == "0":
        allow()

    cwd = data.get("cwd") or ""
    transcript = data.get("transcript_path") or ""
    if not cwd or not os.path.isfile(transcript):
        allow()

    guard_path = find_guard_file(cwd)
    if not guard_path:
        allow()                                  # this directory has not opted in
    globs, off = read_globs(guard_path)
    if off:
        allow()
    guard_dir = os.path.dirname(guard_path)

    pending = []
    for fp in edited_files(transcript):
        ap = os.path.abspath(fp if os.path.isabs(fp) else os.path.join(cwd, fp))
        try:
            rel = os.path.relpath(ap, guard_dir)
        except Exception:
            continue
        if rel.startswith(".."):
            continue                              # not under the guarded directory
        base = os.path.basename(ap)
        if not any(fnmatch.fnmatch(base, g) or fnmatch.fnmatch(rel, g) for g in globs):
            continue
        if has_marker(ap):
            continue
        pending.append(ap)

    if not pending:
        allow()

    listing = "\n".join("  - " + p for p in pending)
    reason = (
        "[xreview guard] The plan files below have not passed cross-model review "
        "(no current, hash-valid XREVIEW-PASS marker or explicit XREVIEW-SKIP final line). "
        "Do not finish up:\n" + listing
    )
    context = (
        reason + "\n\n"
        "Run the loop now, following the xreview skill (use " + guard_dir + " as the cwd):\n"
        "1. `xreview start --label <short-name> <that plan file>` (for page/visual plans, take the "
        "screenshots first and attach them with -i)\n"
        "2. Go through the findings one by one and either fix them or push back with evidence — when "
        "the reviewer cites the wrong line number, Read the file to check before pushing back; "
        "do not pretend a problem does not exist, and do not do over-engineering it never asked for "
        "just to get through\n"
        "3. Continue with `xreview round --session <run-directory> -` and repeat until PASS "
        "(no round limit; consensus is the only criterion)\n"
        "4. `xreview stamp --session <run-directory>` to bind PASS to the reviewed snapshot; "
        "only then start implementing\n\n"
        "When reporting to the user, give one line per round (round N: X findings -> Y fixed, "
        "Z pushed back, W left); do not paste the full text.\n"
        "If the same dispute is deadlocked for 3 rounds in a row, stop and hand the user one sentence "
        "for each side to decide on.\n"
        "Never hand-write a PASS marker. When the user explicitly says "
        "a file does not need review, write one line `XREVIEW-SKIP <reason>` at the end of that file "
        "and report it."
    )
    print(json.dumps({
        "decision": "block",
        "reason": reason,
        "hookSpecificOutput": {
            "hookEventName": "Stop",
            "additionalContext": context,
        },
    }, ensure_ascii=False))
    sys.exit(0)


try:
    main()
except SystemExit:
    raise
except Exception:
    allow()
