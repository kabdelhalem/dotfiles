#!/usr/bin/env bash
# dev-janitor: remove merged, idle git worktrees and leaked docker leftovers.
#
#   dev-janitor.sh            dry run: print what would go and why the rest stays
#   dev-janitor.sh --apply    do it (what dev-janitor.timer runs)
#
# A worktree is removed only if ALL hold: not the main worktree, not locked,
# merged (ancestor of origin's default branch, or a merged PR whose head is
# exactly this HEAD), clean, no git activity for RECENT_HOURS, and not in use.
# "In use" = a Claude transcript from the last TRANSCRIPT_DAYS shows work there (cwd,
# file_path or `cd`), a process has its cwd there, or a docker compose project
# runs from there. Branches are kept; `git worktree remove` is never forced.
set -uo pipefail

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  "") ;;
  *) echo "usage: $0 [--apply]" >&2; exit 2 ;;
esac

# Repos to clean live outside the (public) dotfiles: one path or glob per line,
# e.g. ~/dev/myproject or ~/dev/clients/*. Lines starting with # are skipped.
REPOS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dev-janitor/repos"
[[ -r $REPOS_FILE ]] || { echo "dev-janitor: no $REPOS_FILE, nothing to do" >&2; exit 0; }
REPOS=()
while read -r line; do
  [[ -z $line || $line == \#* ]] && continue
  for r in ${line/#\~/$HOME}; do REPOS+=("$r"); done   # unquoted on purpose: expand globs
done < "$REPOS_FILE"
CLAUDE_DIRS=("$HOME/.claude" "$HOME/.claude-client")
RECENT_HOURS=48
TRANSCRIPT_DAYS=7        # sessions whose transcript changed this recently count as live
TC_ORPHAN_HOURS=3        # leaked testcontainer = no ryuk and older than this
STOPPED_DAYS=7           # stopped non-compose containers older than this go

LOG="$HOME/.local/var/log/dev-janitor.log"
mkdir -p "${LOG%/*}"
exec > >(tee -a "$LOG") 2>&1

export GIT_OPTIONAL_LOCKS=0   # our own `git status` must not bump index mtimes
now=$(date +%s)
cd / || exit 1                # our own cwd must not count as "in use"

run() { if (( APPLY )); then "$@"; else echo "      (dry-run) $*"; fi; }

echo "=== dev-janitor $(date -Is) $( ((APPLY)) && echo APPLY || echo DRY-RUN )"

# ---- What is in use: lines of "<who>\t<path>" ------------------------------
in_use=$(mktemp)
trap 'rm -f "$in_use"' EXIT

for cfg in "${CLAUDE_DIRS[@]}"; do
  for sj in "$cfg"/sessions/*.json; do
    [[ -e $sj ]] || continue
    IFS=$'\t' read -r pid sid start cwd name < <(
      jq -r '[.pid, .sessionId, .procStart, .cwd, (.name // "")] | @tsv' "$sj" 2>/dev/null)
    # Live = pid exists AND its start time matches (guards against pid reuse).
    [[ -r /proc/$pid/stat ]] || continue
    [[ $(awk '{print $22}' "/proc/$pid/stat") == "$start" ]] || continue
    printf 'session:%s\t%s\n' "${name:-$pid}" "$cwd" >> "$in_use"
  done
  # Every transcript written in TRANSCRIPT_DAYS, not just live pids: after a
  # reboot or --resume, a session's earlier worktrees must stay protected.
  # Structured fields only: bare paths also show up in plain tool output
  # (e.g. a `git worktree list`), which must not protect everything. Tool
  # output is an escaped string in the jsonl, so these only hit real fields.
  find "$cfg/projects" -name '*.jsonl' -mtime -"$TRANSCRIPT_DAYS" -print0 2>/dev/null |
    xargs -0 -r grep -oHE '"(cwd|file_path|notebook_path)":"/[^"]+|"command":"cd /[^ "\\;&|)]+' |
    sed -E 's#^[^:]*/projects/[^/]+/([0-9a-f]{8})[^:]*:#transcript:\1\t#; s#\t"[a-z_]+":"(cd )?#\t#' |
    sort -u >> "$in_use"
done

for p in /proc/[0-9]*; do
  c=$(readlink "$p/cwd" 2>/dev/null) && printf 'pid:%s\t%s\n' "${p#/proc/}" "$c"
done >> "$in_use"

have_docker=0
docker info >/dev/null 2>&1 && have_docker=1
if (( have_docker )); then
  docker ps -a --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}' |
    awk -F'\t' '$2 != "" {print "compose:" $1 "\t" $2}' >> "$in_use"
fi

# First in-use entry at or under $1, as "<who> (<path>)".
used_by() {
  awk -F'\t' -v w="$1" '$2 == w || index($2, w "/") == 1 {print $1 " (" $2 ")"; exit}' "$in_use"
}

# Last git activity in a worktree: newer of its index mtime and its last
# HEAD reflog entry. Not logs/HEAD's mtime: gc's reflog expire rewrites it.
last_activity() {
  local gd=$1 i=0 r=0
  [[ -e $gd/index ]] && i=$(stat -c %Y "$gd/index")
  [[ -s $gd/logs/HEAD ]] && r=$(tail -n1 "$gd/logs/HEAD" | awk -F'\t' '{n = split($1, a, " "); print a[n-1] + 0}')
  echo $(( i > r ? i : r ))
}

# Fields are '|'-separated: a tab is IFS whitespace, so empty fields
# (detached HEAD, no compose label) would collapse and shift columns.

# ---- Worktrees --------------------------------------------------------------
removed=0
for repo in "${REPOS[@]}"; do
  [[ -d $repo/.git ]] || continue   # main checkouts only; siblings come from its list
  echo "--- $(basename "$repo")"

  timeout 60 env GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' \
    git -C "$repo" fetch --quiet --prune origin 2>/dev/null ||
    echo "    fetch failed; using cached refs"
  def=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  # "<branch> <head sha>" for merged PRs (catches squash/rebase merges).
  merged_prs=$(cd "$repo" && timeout 60 gh pr list --state merged --limit 500 \
    --json headRefName,headRefOid --jq '.[] | "\(.headRefName) \(.headRefOid)"' 2>/dev/null)

  first=1
  while IFS='|' read -r wt sha branch flag; do
    if (( first )); then first=0; continue; fi   # main worktree
    n=${wt#"$(dirname "$repo")"/}
    # Only our own layouts (wt-claim slots, Claude worktrees); other tools'
    # worktrees may look merged+idle exactly when they're parked between jobs.
    case $wt in
      "$repo"-*|"$repo"/.claude/worktrees/*) ;;
      *) echo "    keep   $n: outside managed locations"; continue ;;
    esac
    [[ $flag == locked ]] && { echo "    keep   $n: locked"; continue; }
    [[ $flag == prunable || ! -d $wt ]] && continue   # handled by `worktree prune`

    u=$(used_by "$wt")
    [[ -n $u ]] && { echo "    keep   $n: in use by $u"; continue; }

    gd=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) || { echo "    keep   $n: not a readable worktree"; continue; }
    age=$(( (now - $(last_activity "$gd")) / 3600 ))
    (( age < RECENT_HOURS )) && { echo "    keep   $n: git activity ${age}h ago"; continue; }

    if git -C "$repo" merge-base --is-ancestor "$sha" "$def" 2>/dev/null; then
      how="merged into $def"
    elif [[ -n $branch ]] && grep -qxF "$branch $sha" <<<"$merged_prs"; then
      how="PR merged"
    else
      echo "    keep   $n: not merged${branch:+ ($branch)}"; continue
    fi

    [[ -n $(git -C "$wt" status --porcelain 2>/dev/null) ]] &&
      { echo "    keep   $n: $how but has uncommitted/untracked changes"; continue; }

    # Ignored files are deleted with the worktree: never take local terraform
    # state, tfvars, env files or keys with it.
    precious=$(git -C "$wt" ls-files --others --ignored --exclude-standard 2>/dev/null |
      grep -vE '(^|/)(node_modules|\.venv|managed_components|\.dart_tool)/' 2>/dev/null |
      grep -m1 -E '(^|/)(\.env[^/]*|[^/]*\.tfstate(\.backup)?|[^/]*\.tfvars|[^/]*\.(pem|key|p12|jks|keystore))$')
    [[ -n $precious ]] && { echo "    keep   $n: $how but holds ignored $precious"; continue; }

    # Docker builds leave root-owned files; git would half-delete the tree.
    root_owned=$(find "$wt" ! -user "$USER" -print -quit 2>/dev/null)
    [[ -n $root_owned ]] && { echo "    keep   $n: $how but ${root_owned#"$wt"/} isn't yours (needs sudo rm)"; continue; }

    echo "    REMOVE $n: $how, clean, idle ${age}h"
    run git -C "$repo" worktree remove "$wt" && (( APPLY )) && (( removed++ ))
  done < <(git -C "$repo" worktree list --porcelain | awk '
    function out() { if (p != "") print p "|" h "|" b "|" f }
    /^worktree / { out(); p = substr($0, 10); h = b = f = "" }
    /^HEAD /     { h = $2 }
    /^branch /   { b = substr($2, 12) }
    /^locked/    { f = "locked" }
    /^prunable/  { f = "prunable" }
    END          { out() }')

  run git -C "$repo" worktree prune
done

# ---- Docker -----------------------------------------------------------------
if (( have_docker )); then
  echo "--- docker"

  # Leaked testcontainers: their session's ryuk reaper is gone, so nothing
  # will ever stop them (typically the test process or ryuk got OOM-killed).
  ryuks=$(docker ps --filter label=org.testcontainers.ryuk=true --format '{{.Names}}')
  while IFS='|' read -r id cname sess created; do
    grep -qxF "testcontainers-ryuk-$sess" <<<"$ryuks" && continue
    h=$(( (now - $(date -d "${created% *}" +%s)) / 3600 ))
    (( h >= TC_ORPHAN_HOURS )) || continue
    echo "    REMOVE testcontainer $cname: running ${h}h, its ryuk is gone"
    run docker rm -f -v "$id" >/dev/null
  done < <(docker ps --filter label=org.testcontainers.session-id \
    --format '{{.ID}}|{{.Names}}|{{.Label "org.testcontainers.session-id"}}|{{.CreatedAt}}')

  # Stopped one-off containers. Compose (and supabase, which labels as compose)
  # stacks are left alone: `compose down` is the owner's call.
  while IFS='|' read -r id cname proj created; do
    [[ -n $proj ]] && continue
    d=$(( (now - $(date -d "${created% *}" +%s)) / 86400 ))
    (( d >= STOPPED_DAYS )) || continue
    echo "    REMOVE stopped container $cname: created ${d}d ago"
    run docker rm -v "$id" >/dev/null
  done < <(docker ps -a --filter status=exited --filter status=created --filter status=dead \
    --format '{{.ID}}|{{.Names}}|{{.Label "com.docker.compose.project"}}|{{.CreatedAt}}')

  # Without -a these only touch anonymous volumes and dangling images.
  echo "    unused anonymous volumes: $(docker volume ls -q --filter dangling=true --filter label=com.docker.volume.anonymous | wc -l)"
  run docker volume prune -f
  run docker image prune -f
  run docker builder prune -f --filter until=$((STOPPED_DAYS * 24))h
  docker system df
fi

echo "=== done: $( ((APPLY)) && echo "$removed worktree(s) removed" || echo "dry run, nothing changed")"
