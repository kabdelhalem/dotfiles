# git worktree slot helpers (zsh).
#
# wt-claim <branch> [base-ref]
#   Grab the next free letter slot (a..z) next to the main worktree, create
#   or check out <branch>, and cd into it. base-ref defaults to origin/main
#   and is only used when the branch doesn't exist yet.
#
# wt-release [--force]
#   Remove the current letter-slot worktree after safety checks (dirty tree,
#   unpushed commits). --force skips the checks.
#
# wt-help
#   Show usage and current slot status.
#
# Source this file from ~/.zshrc.

wt-claim() {
  local branch="$1" base="${2:-origin/main}"
  if [[ -z "$branch" ]]; then
    echo "usage: wt-claim <branch> [base-ref]" >&2
    return 1
  fi

  # Main worktree is always the first stanza in --porcelain output.
  local main_wt
  main_wt=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}')
  if [[ -z "$main_wt" ]]; then
    echo "wt-claim: not inside a git repo" >&2
    return 1
  fi

  local repo_name parent
  repo_name=$(basename "$main_wt")
  parent=$(dirname "$main_wt")

  local -a taken
  taken=("${(@f)$(git worktree list --porcelain | awk '/^worktree / {print $2}')}")

  # NB: never name a local `path` in zsh — it's tied to $PATH and would empty it.
  local letter slot_path found=""
  for letter in {a..z}; do
    slot_path="$parent/$repo_name-$letter"
    # Skip if git tracks it, or if any dir/file already sits there.
    if (( ${taken[(Ie)$slot_path]} )) || [[ -e "$slot_path" ]]; then
      continue
    fi
    found="$slot_path"
    break
  done

  if [[ -z "$found" ]]; then
    echo "wt-claim: no free slots a-z under $parent" >&2
    return 1
  fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$found" "$branch" || return 1
  else
    echo "wt-claim: creating branch '$branch' from $base"
    git worktree add -b "$branch" "$found" "$base" || return 1
  fi

  cd "$found" && echo "→ $found"
}

wt-release() {
  local force=0
  [[ "$1" == "--force" || "$1" == "-f" ]] && force=1

  local here main_wt
  here=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "wt-release: not inside a git repo" >&2; return 1
  }
  main_wt=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')

  if [[ "$here" == "$main_wt" ]]; then
    echo "wt-release: refusing to remove the main worktree ($here)" >&2
    return 1
  fi

  local parent repo_name base
  parent=$(dirname "$main_wt")
  repo_name=$(basename "$main_wt")
  if [[ "$(dirname "$here")" != "$parent" ]]; then
    echo "wt-release: $here is not a sibling of $main_wt" >&2
    return 1
  fi
  base=$(basename "$here")
  if [[ "$base" != "$repo_name"-? ]]; then
    echo "wt-release: $here isn't a letter-slot worktree ($repo_name-<letter>)" >&2
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "wt-release: uncommitted changes in $here (use --force to override)" >&2
    (( force )) || return 1
  fi

  local branch upstream ahead
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [[ -n "$upstream" ]]; then
      ahead=$(git rev-list --count "$upstream..HEAD" 2>/dev/null)
      if [[ "$ahead" -gt 0 ]]; then
        echo "wt-release: branch '$branch' has $ahead unpushed commit(s) (use --force to override)" >&2
        (( force )) || return 1
      fi
    else
      echo "wt-release: branch '$branch' has no upstream; any local commits would be lost (use --force to override)" >&2
      (( force )) || return 1
    fi
  fi

  cd "$main_wt" || return 1
  if (( force )); then
    git worktree remove --force "$here" && echo "removed $here"
  else
    git worktree remove "$here" && echo "removed $here"
  fi
}

wt-help() {
  cat <<'USAGE'
git worktree slot helpers:

  wt-claim <branch> [base-ref]   Grab next free letter slot (a..z), create
                                 or check out <branch>, and cd in.
                                 [base-ref] defaults to origin/main.

  wt-release [--force]           Remove the current letter-slot worktree
                                 (blocks on dirty tree / unpushed commits).

  wt-help                        Show this message and current slot status.
USAGE

  local main_wt
  main_wt=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}')
  [[ -z "$main_wt" ]] && return 0

  local repo_name parent
  repo_name=$(basename "$main_wt")
  parent=$(dirname "$main_wt")

  local -a taken
  taken=("${(@f)$(git worktree list --porcelain | awk '/^worktree / {print $2}')}")

  echo
  echo "main: $main_wt"
  echo
  echo "letter slots:"
  local letter slot_path used=0 branch
  for letter in {a..z}; do
    slot_path="$parent/$repo_name-$letter"
    if (( ${taken[(Ie)$slot_path]} )); then
      branch=$(git -C "$slot_path" symbolic-ref --short HEAD 2>/dev/null || echo "?")
      printf "  %s  %s  [%s]\n" "$letter" "$slot_path" "$branch"
      (( used++ ))
    fi
  done
  (( used == 0 )) && echo "  (none claimed; next wt-claim will take 'a')"

  echo
  echo "other worktrees:"
  local wt base others=0
  for wt in "${taken[@]}"; do
    [[ "$wt" == "$main_wt" ]] && continue
    base=$(basename "$wt")
    [[ "$base" == "$repo_name"-? ]] && continue
    branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo "?")
    printf "  %s  [%s]\n" "$wt" "$branch"
    (( others++ ))
  done
  (( others == 0 )) && echo "  (none)"
  return 0
}
