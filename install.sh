#!/usr/bin/env zsh
# Install CLIs and skills without silently overwriting a user's existing files.
set -euo pipefail

ROOT="${0:A:h}"
HOOKS=0
REPLACE=0

usage() {
  print "Usage: ./install.sh [--hooks] [--replace]"
  print "  CLIs   -> ~/bin"
  print "  skills -> ~/.claude/skills, ~/.codex/skills, ~/.agents/skills"
  print "  --hooks    also install xreview-guard.py -> ~/.claude/hooks"
  print "  --replace  back up differing destinations, then install exact copies"
}

while (( $# )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --hooks) HOOKS=1 ;;
    --replace) REPLACE=1 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

SOURCES=()
DESTS=()
KINDS=()

for name in ai-review ai-duel xreview; do
  SOURCES+=("$ROOT/bin/$name")
  DESTS+=("$HOME/bin/$name")
  KINDS+=(executable)
done

for skill_root in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills"; do
  for name in ai-review ai-duel xreview; do
    SOURCES+=("$ROOT/skills/$name")
    DESTS+=("$skill_root/$name")
    KINDS+=(directory)
  done
done

if (( HOOKS )); then
  SOURCES+=("$ROOT/hooks/xreview-guard.py")
  DESTS+=("$HOME/.claude/hooks/xreview-guard.py")
  KINDS+=(executable)
fi

same_path() {
  local src="$1" dest="$2" kind="${3:-}"
  if [[ -f "$src" && -f "$dest" && ! -L "$dest" ]]; then
    cmp -s "$src" "$dest" && { [[ "$kind" != executable ]] || [[ -x "$dest" ]]; }
  elif [[ -d "$src" && -d "$dest" && ! -L "$dest" ]]; then
    diff -qr "$src" "$dest" > /dev/null 2>&1
  else
    return 1
  fi
}

# Preflight every destination before the first write. One conflict means no partial install.
CONFLICTS=()
for (( i=1; i<=${#SOURCES}; i++ )); do
  dest="${DESTS[$i]}"
  if [[ -e "$dest" || -L "$dest" ]]; then
    same_path "${SOURCES[$i]}" "$dest" "${KINDS[$i]}" || CONFLICTS+=("$i")
  fi
done

if (( ${#CONFLICTS} && ! REPLACE )); then
  print -u2 "Install stopped before making changes. Differing destination(s):"
  for i in "${CONFLICTS[@]}"; do print -u2 "  ${DESTS[$i]}"; done
  print -u2 "Re-run with --replace to move those paths into a timestamped backup first."
  exit 1
fi

BACKUP_ROOT=""
if (( ${#CONFLICTS} )); then
  BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/cross-model-review/backups/$(date +%Y%m%d-%H%M%S)-$$"
fi

for (( i=1; i<=${#SOURCES}; i++ )); do
  src="${SOURCES[$i]}"
  dest="${DESTS[$i]}"
  kind="${KINDS[$i]}"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if same_path "$src" "$dest" "$kind"; then
      print "unchanged -> $dest"
      continue
    fi
  fi

  mkdir -p "${dest:h}"
  stage="${dest}.cross-model-review-new-$$-$RANDOM"
  if [[ "$kind" == directory ]]; then
    cp -R "$src" "$stage"
  else
    cp "$src" "$stage"
    chmod +x "$stage"
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    rel="${dest#$HOME/}"
    backup="$BACKUP_ROOT/$rel"
    mkdir -p "${backup:h}"
    mv "$dest" "$backup"
    print "backup   -> $backup"
  fi
  mv "$stage" "$dest"
  print "installed -> $dest"
done

if ! print -r -- "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  print -u2 "warning: $HOME/bin is not on PATH"
  print -u2 "  add this to ~/.zshrc: export PATH=\"\$HOME/bin:\$PATH\""
fi

(( HOOKS )) && print "hook installed but still needs registering in Claude settings; see README.md"
[[ -n "$BACKUP_ROOT" ]] && print "backup root: $BACKUP_ROOT"
print "Done. Open a new agent session and confirm the three skills appear."
