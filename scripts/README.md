<div align="center">

# 🛠️  Scripts & automation

_Worktree slot helpers, Hyprland glue, and system housekeeping._

</div>

---

## 🌳  Git worktree slots

A set of zsh helpers (`git-worktree-slots.sh`) turn `git worktree` into a
frictionless, **lettered parking lot** of checkouts sitting beside your main repo —
perfect for running several Claude Code / feature branches in parallel without
stashing or clobbering each other.

```
~/dev/
├── myrepo/      ← main worktree (origin/main)
├── myrepo-a/    ← wt-claim feature-x    → slot "a"
├── myrepo-b/    ← wt-claim bugfix-y     → slot "b"
└── myrepo-c/    ← wt-claim spike-z      → slot "c"
```

| Command | What it does |
|---|---|
| `wt-claim <branch> [base]` | Grabs the next free letter slot `a…z`, creates/checks out the branch (from `origin/main` by default), and `cd`s in. |
| `wt-release [--force]` | Removes the current slot — but **refuses** if the tree is dirty or has unpushed commits. `--force` overrides. |
| `wt-status [--no-fetch]` | Lists every worktree with a **merged / in-progress verdict** (uses `gh` to catch squash & rebase merges) so stale slots are obvious. |
| `wt-help` | Usage + a live map of claimed slots and their branches. |

**Why it's nice:**
- 🅰️ **Deterministic paths** — always `repo-a`, `repo-b`… so muscle memory and tooling both work.
- 🛡️ **Safety rails** — you can't accidentally nuke work with uncommitted or unpushed changes.
- 🔍 **Cleanup radar** — `wt-status` tells you exactly which slots are safe to release.
- 🤖 **Claude Code aware** — a `SessionStart` hook (`wt-env-sync.sh`) auto-copies gitignored
  local files (`.env`, sample configs…) from the main worktree into a fresh slot, matched
  by _structure_ (untracked + gitignored + missing) rather than by name — so a new checkout
  is instantly runnable.

> Source `git-worktree-slots.sh` from your `~/.zshrc` to enable the `wt-*` commands.

---

## 📜  All scripts

| Script | Role |
|---|---|
| `git-worktree-slots.sh` | The `wt-*` worktree slot helpers (above). |
| `wt-env-sync.sh` | Claude Code `SessionStart` hook — syncs local env files into new worktrees. |
| `hypr-urgent-flash.sh` | Flags urgent windows with a red border until focused. |
| `sysmaintenance.sh` | Interactive, abort-safe Arch "spring-clean" (cache trim, `pacdiff`, optional full upgrade; auto-detects `yay`/`paru`). |
| `../update-check/` | systemd `service` + `timer` that counts pending pacman/AUR updates for the bar. |
