#!/usr/bin/env bash
# wt-env-sync.sh — Claude Code SessionStart hook.
#
# When a session starts inside a wt-claim letter-slot worktree, copy local
# gitignored files (.env, sample.config, whatever the project uses) from the
# main worktree into this one if they're missing. Files are matched by
# structure — untracked + gitignored in main + absent here — not by name,
# so it works regardless of what each project calls its env files.
#
# Registered in ~/.claude/settings.json under hooks.SessionStart.
# Must always exit 0 and stay quiet outside linked worktrees.

MAX_BYTES=5242880 # 5MB — don't drag local dev DBs / archives along

git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$git_dir" = "$common_dir" ] && exit 0 # main worktree or plain repo

cur=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
main_wt=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}')
{ [ -z "$main_wt" ] || [ "$main_wt" = "$cur" ]; } && exit 0

copied=()
skipped=()
# --directory collapses fully-ignored dirs (node_modules/ etc.) into one
# trailing-slash entry, which we drop — only loose ignored files get copied.
while IFS= read -r f; do
  case "$f" in
  */) continue ;;
  *.log | *.sock | *.pid | *.swp | *.tmp | .DS_Store) continue ;;
  esac
  src="$main_wt/$f"
  dst="$cur/$f"
  { [ -f "$src" ] && [ ! -e "$dst" ]; } || continue
  size=$(stat -c %s "$src" 2>/dev/null || echo 0)
  if [ "$size" -gt "$MAX_BYTES" ]; then
    skipped+=("$f")
    continue
  fi
  mkdir -p "$(dirname "$dst")" 2>/dev/null &&
    cp -p "$src" "$dst" 2>/dev/null &&
    copied+=("$f")
done < <(git -C "$main_wt" ls-files --others --ignored --exclude-standard --directory 2>/dev/null)

# Stay silent when nothing was copied — this runs on every session start,
# so an already-synced worktree shouldn't produce a message each time.
[ ${#copied[@]} -eq 0 ] && exit 0

msg="wt-env-sync: copied from main worktree: ${copied[*]}"
[ ${#skipped[@]} -gt 0 ] && msg="$msg (skipped >5MB: ${skipped[*]})"

command -v jq >/dev/null 2>&1 || {
  echo "$msg"
  exit 0
}
jq -cn --arg msg "$msg" \
  '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "SessionStart"}}'
exit 0
