#!/usr/bin/env bash
# Install the html-artifact skill into every detected agent's user-level skills directory.
#
# Usage:
#   bash scripts/install.sh              # auto-detect agents, install into each found
#   bash scripts/install.sh --agent kimi # install only for one agent (codex|kimi|claude)
#   bash scripts/install.sh --list       # show detected agents and target paths, change nothing
#
# Targets:
#   codex  → ${CODEX_HOME:-~/.codex}/skills/html-artifact
#   kimi   → ~/.agents/skills/html-artifact      (Kimi Code CLI user-scope skills)
#   claude → ~/.claude/skills/html-artifact      (Claude Code user-scope skills)
#
# Copies SKILL.md, references/, assets/, and scripts/ (tests/ and docs stay in the repo).
# Re-running overwrites the previous copy; start a new agent session after installing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_NAME="html-artifact"

MODE=install
ONLY=""
while (( $# )); do
  case "$1" in
    --list) MODE=list; shift ;;
    --agent) (( $# >= 2 )) || { echo "--agent requires codex|kimi|claude" >&2; exit 2; }
      ONLY=$2; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

target_for() {
  case "$1" in
    codex)  printf '%s/skills/%s' "${CODEX_HOME:-$HOME/.codex}" "$SKILL_NAME" ;;
    kimi)   printf '%s/.agents/skills/%s' "$HOME" "$SKILL_NAME" ;;
    claude) printf '%s/.claude/skills/%s' "$HOME" "$SKILL_NAME" ;;
  esac
}

detected() {
  local found=()
  [[ -n "${CODEX_HOME:-}" || -d "$HOME/.codex" ]] && found+=(codex)
  [[ -d "$HOME/.agents/skills" || -d "$HOME/.agents" ]] && found+=(kimi)
  [[ -d "$HOME/.claude" ]] && found+=(claude)
  printf '%s\n' "${found[@]:-}"
}

AGENTS=$(detected)
if [[ -n "$ONLY" ]]; then
  case "$ONLY" in codex|kimi|claude) ;; *) echo "Unknown agent: $ONLY" >&2; exit 2 ;; esac
  AGENTS=$ONLY
fi
if [[ -z "$AGENTS" ]]; then
  echo "No supported agent found. Install one of: codex, kimi, claude — or pass --agent to force." >&2
  exit 1
fi

status=0
while IFS= read -r agent; do
  [[ -n "$agent" ]] || continue
  dest=$(target_for "$agent")
  if [[ "$MODE" == list ]]; then
    [[ -d "$dest" ]] && state="installed" || state="not installed"
    printf '%-7s %s (%s)\n' "$agent" "$dest" "$state"
    continue
  fi
  mkdir -p "$dest"
  # Copy only what the skill needs at runtime; keep docs/tests repo-only.
  cp "$SKILL_ROOT/SKILL.md" "$dest/SKILL.md"
  rm -rf "$dest/references" "$dest/assets" "$dest/scripts"
  cp -R "$SKILL_ROOT/references" "$SKILL_ROOT/assets" "$SKILL_ROOT/scripts" "$dest/"
  echo "installed $agent -> $dest"
done <<< "$AGENTS"

if [[ "$MODE" == install ]]; then
  echo "Start a new agent session so the skill is loaded."
fi
exit $status
