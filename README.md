<div align="center">

# 🐧 `kareems-archpad` · dotfiles

**A hand-tuned Hyprland rice on Arch Linux**
_ThinkPad X1 Carbon Gen 13 · Intel Core Ultra 7 (Lunar Lake) · Wayland_

<br>

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-0.56-58E1FF?style=for-the-badge&logo=wayland&logoColor=black)
![Wayland](https://img.shields.io/badge/Wayland-FFB300?style=for-the-badge&logo=wayland&logoColor=white)
![zsh](https://img.shields.io/badge/shell-zsh-89e051?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Neovim](https://img.shields.io/badge/editor-Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)

</div>

---

## 🖥️  System at a glance

```
       /\           kareem@kareems-archpad
      /  \          ─────────────────────────────────────────────
     /\   \         OS        Arch Linux (rolling)
    /      \        Host      Lenovo ThinkPad X1 Carbon Gen 13
   /   ,,   \       Init      systemd
  /   |  |  -\      WM        Hyprland 0.56.0  (Wayland)
 /_-''    ''-_\     Shell     zsh

   CPU     Intel Core Ultra 7 258V  ·  8 cores  ·  Lunar Lake
   GPU     Intel Arc Graphics 140V  (integrated)
   RAM     30 GiB LPDDR5
   Disk    890 GB NVMe  (/dev/nvme0n1p3)
   Display 1920 × 1200 @ 60 Hz  ·  eDP-1
   Pkgs    1336 (pacman + AUR via yay)
```

| | |
|---|---|
| **Machine** | Lenovo ThinkPad X1 Carbon Gen 13 (`21NT`) |
| **CPU** | Intel Core Ultra 7 258V · 8C/8T · Lunar Lake |
| **GPU** | Intel Arc Graphics 130V/140V (iGPU) |
| **Memory** | 30 GiB LPDDR5 |
| **Storage** | 890 GB NVMe SSD |
| **Panel** | 1920×1200 eDP · multi-monitor aware (DP-1 / HDMI-A-1) |
| **Firmware** | N4BET64W (1.34) |

---

## 🧩  The stack

| Layer | Tool |
|---|---|
| 🪟 **Compositor** | [Hyprland](https://hypr.land) `0.56` — dynamic tiling on Wayland |
| 📊 **Bar** | [Waybar](https://github.com/Alexays/Waybar) — custom modules + scripts |
| 🚀 **Launcher** | [Rofi](https://github.com/davatorium/rofi) (Wayland) — apps, clipboard, powermenu |
| 🔔 **Notifications** | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| 🎚️ **On-screen display** | [SwayOSD](https://github.com/ErikReider/SwayOSD) — volume / brightness / mic |
| 🖼️ **Wallpaper** | [hyprpaper](https://github.com/hyprwm/hyprpaper) |
| 🔒 **Lock / idle** | [hyprlock](https://github.com/hyprwm/hyprlock) |
| 💻 **Terminal** | [Alacritty](https://github.com/alacritty/alacritty) |
| 📝 **Editor** | [Neovim](https://neovim.io) |
| 🐚 **Shell** | zsh |
| 📈 **GPU monitor** | [nvtop](https://github.com/Syllo/nvtop) |
| 🤖 **Assistant** | Claude Code — with worktree-aware session hooks |

---

## 📚  Explore

| | |
|---|---|
| 🪟 **[Hyprland](.config/hypr/)** | Look & feel and the full keybinding reference. |
| 🛠️ **[Scripts & automation](scripts/)** | Git worktree slots, Hyprland glue, and system housekeeping. |

---

## 📁  Repository layout

```
dotfiles/
├── .config/
│   ├── hypr/          hyprland.conf · hyprlock · hyprpaper · README.md
│   ├── waybar/        config · style.css · scripts/ (battery, vpn, mic, …)
│   ├── rofi/          config.rasi · theme.rasi
│   ├── swaync/        config.json · style.css
│   ├── swayosd/       config.toml · style.css
│   └── nvtop/         interface.ini
├── scripts/           worktree slots · urgent-flash · maintenance · README.md
├── update-check/      systemd service + timer for update counts
├── wallpaper.jpg
└── README.md          ← you are here
```

---

<div align="center">

_Built for fast, parallel, keyboard-driven work on a tiling Wayland desktop._ ⚡

</div>
