<div align="center">

# 🪟  Hyprland

_Look & feel and keybindings for the Wayland tiling setup._

</div>

---

## 🎨  Look & feel

The rice leans on a cool **cyan / teal** accent over a dark base, thin borders, and gentle gaps.

| Element | Value |
|---|---|
| Active border | `#0891B2` — blue glow on the focused window |
| Inactive border | `#055167` — muted teal |
| Urgent border | `#E06C75` — red until you look at it |
| Gaps | `5` inner · `10` outer |
| Rounding | `1` px, subtle |
| Waybar | floating top bar, `12 px` margin, centered workspace pills |

> 🔴 **Urgent-window flash** — when a background window (like an unfocused Claude Code
> session ringing the terminal bell) raises the urgency flag, `hypr-urgent-flash.sh`
> paints it with a red border until you focus it. No missed pings.

---

## ⌨️  Keybindings

Modifier is **`SUPER`** (the ⊞ key).

### Windows & focus
| Keys | Action |
|---|---|
| `SUPER` + `Q` | Open terminal |
| `SUPER` + `C` | Close active window |
| `SUPER` + `E` | File manager |
| `SUPER` + `R` | App launcher (rofi) |
| `SUPER` + `V` | Clipboard history (cliphist → rofi) |
| `SUPER` + `L` | Lock screen (hyprlock) |
| `SUPER` + `←↑↓→` | Move focus |
| `SUPER` + `J` | Toggle split direction |
| `SUPER` + `SHIFT` + `V` | Toggle floating |
| `SUPER` + `SHIFT` + `←↑↓→` | Resize active window |
| `SUPER` + `U` | Jump to urgent / last window |
| `SUPER` + drag | Move (LMB) / resize (RMB) window |

### Workspaces
| Keys | Action |
|---|---|
| `SUPER` + `1…0` | Switch to workspace 1–10 |
| `SUPER` + `SHIFT` + `1…0` | Move window to workspace |
| `SUPER` + `S` | Toggle "magic" scratchpad (special workspace) |
| `SUPER` + `SHIFT` + `S` | Send window to scratchpad |
| `SUPER` + scroll | Cycle workspaces |

_Workspaces 1–5 live on the laptop panel; 6–10 are pinned to the external monitor._

### Media & capture
| Keys | Action |
|---|---|
| `🔊 / 🔉 / 🔇` | Volume up / down / mute (SwayOSD) |
| `🎤` | Mic mute toggle |
| `🔆 / 🔅` | Brightness (SwayOSD) |
| `⏯ ⏭ ⏮` | Playback control (playerctl) |
| `Print` | Region screenshot → save + copy |
| `SHIFT` + `Print` | Fullscreen screenshot → save + copy |

---

## 📄  Files

| File | Purpose |
|---|---|
| `hyprland.lua` | Main config — monitors, keybinds, window rules, look & feel (Lua, 0.55+). |
| `hyprland.conf` | Legacy hyprlang config, kept as a fallback. Loads only if `hyprland.lua` is absent. |
| `local.lua` | Machine-local overrides (gitignored), `require`d by `hyprland.lua`. |
| `hyprlock.conf` | Lock screen (separate binary — stays hyprlang). |
| `hyprpaper.conf` | Wallpaper (separate binary — stays hyprlang). |
| `local.conf` | Legacy machine-local overrides for the `.conf` fallback (gitignored). |

> ℹ️ **Lua config** — Hyprland 0.55+ configures the compositor in Lua. If
> `~/.config/hypr/hyprland.lua` exists it loads _instead of_ `hyprland.conf`.
> Validate a config without launching it: `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`.
