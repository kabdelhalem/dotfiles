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
# wt-status [--no-fetch]
#   Show every worktree with a merged / in-progress verdict so stale slots
#   are easy to spot and release. Uses `gh` for the PR state when available
#   (catches squash/rebase merges), git heuristics otherwise.
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

wt-status() {
  local do_fetch=1
  [[ "$1" == "--no-fetch" ]] && do_fetch=0

  local main_wt
  main_wt=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}')
  if [[ -z "$main_wt" ]]; then
    echo "wt-status: not inside a git repo" >&2
    return 1
  fi

  # Fetch with --prune so deleted-on-origin branches show up as "gone".
  # Tolerate failure (offline etc.) and fall back to cached refs.
  if (( do_fetch )); then
    git -C "$main_wt" fetch --quiet --prune origin 2>/dev/null ||
      echo "wt-status: fetch failed; showing cached state" >&2
  fi

  # Default branch ref (origin/main unless origin/HEAD says otherwise).
  local def
  def=$(git -C "$main_wt" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  [[ -z "$def" ]] && def="origin/main"
  git -C "$main_wt" rev-parse --verify --quiet "$def" >/dev/null 2>&1 || def=""

  local have_gh=0
  command -v gh >/dev/null 2>&1 && have_gh=1

  local repo_name
  repo_name=$(basename "$main_wt")

  local -a wts
  wts=("${(@f)$(git worktree list --porcelain | awk '/^worktree / {print $2}')}")

  local wt sha branch label slot pr_state merged verdict ahead behind
  local upstream_info upstream track gone count=0
  local -a notes
  for wt in "${wts[@]}"; do
    [[ "$wt" == "$main_wt" ]] && continue
    (( count++ ))

    sha=$(git -C "$wt" rev-parse HEAD 2>/dev/null) || continue
    branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null)
    label="${branch:-detached@${sha[1,7]}}"
    slot=$(basename "$wt")
    [[ "$slot" == "$repo_name"-? ]] && slot="${slot##*-}" || slot="-"

    notes=()
    [[ -n $(git -C "$wt" status --porcelain 2>/dev/null) ]] && notes+=("dirty")

    # Upstream state: ahead count, or "gone" if deleted on origin.
    upstream="" gone=0
    if [[ -n "$branch" ]]; then
      upstream_info=$(git -C "$wt" for-each-ref \
        --format='%(upstream:short)|%(upstream:track)' "refs/heads/$branch")
      upstream="${upstream_info%%|*}"
      track="${upstream_info#*|}"
      [[ "$track" == *gone* ]] && gone=1
      if [[ -n "$upstream" && $gone -eq 0 ]]; then
        ahead=$(git -C "$wt" rev-list --count "$upstream..$sha" 2>/dev/null)
        [[ "$ahead" -gt 0 ]] && notes+=("$ahead unpushed")
      elif [[ -z "$upstream" ]]; then
        notes+=("no upstream")
      fi
    fi

    # Merge verdict. PR state via gh is authoritative (survives squash and
    # rebase merges); fall back to ancestry / gone-upstream heuristics.
    pr_state=""
    if (( have_gh )) && [[ -n "$branch" ]]; then
      pr_state=$(cd "$wt" 2>/dev/null &&
        gh pr view "$branch" --json state --jq .state 2>/dev/null)
    fi
    case "$pr_state" in
      MERGED) merged="yes" ;;
      OPEN)   merged="no" ;;
      CLOSED) merged="closed" ;;
      *)
        if [[ -n "$def" ]] && git -C "$main_wt" merge-base --is-ancestor "$sha" "$def" 2>/dev/null; then
          merged="yes"
        elif (( gone )); then
          merged="maybe"
        else
          merged="no"
        fi
        ;;
    esac

    if [[ -n "$def" && "$merged" == "no" ]]; then
      behind=$(git -C "$wt" rev-list --count "$sha..$def" 2>/dev/null)
      [[ "$behind" -gt 0 ]] && notes+=("$behind behind $def")
    fi

    case "$merged" in
      yes)
        if (( ${#notes[@]} == 0 )); then
          verdict="✓ merged — safe to wt-release"
        else
          verdict="✓ merged — but ${(j:, :)notes}"
        fi
        ;;
      maybe)  verdict="? upstream gone (merged & deleted on origin?)"
              (( ${#notes[@]} )) && verdict="$verdict — ${(j:, :)notes}" ;;
      closed) verdict="✗ PR closed without merging"
              (( ${#notes[@]} )) && verdict="$verdict — ${(j:, :)notes}" ;;
      *)      verdict="● in progress"
              (( ${#notes[@]} )) && verdict="$verdict (${(j:, :)notes})" ;;
    esac

    printf "  %-2s %-28s %s\n" "$slot" "$label" "$verdict"
  done

  (( count == 0 )) && echo "  (no worktrees claimed)"
  return 0
}

wt-help() {
  cat <<'USAGE'
git worktree slot helpers:

  wt-claim <branch> [base-ref]   Grab next free letter slot (a..z), create
                                 or check out <branch>, and cd in.
                                 [base-ref] defaults to origin/main.

  wt-release [--force]           Remove the current letter-slot worktree
                                 (blocks on dirty tree / unpushed commits).

  wt-status [--no-fetch]         Show merged / in-progress verdict for every
                                 worktree so stale slots are easy to spot.

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
