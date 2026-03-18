#!/bin/bash
# ── brightness.sh ─────────────────────────────────────────
# Description: Shows current brightness with ASCII bar + tooltip
# Usage: Waybar `custom/brightness` (event-driven, no polling)
# Dependencies: brightnessctl, inotify-tools, seq, printf, awk
#  ─────────────────────────────────────────────────────────

BRIGHTNESS_FILE="/sys/class/backlight/$(ls /sys/class/backlight | head -1)/brightness"

emit() {
  brightness=$(brightnessctl get)
  max_brightness=$(brightnessctl max)
  percent=$((brightness * 100 / max_brightness))

  # Build ASCII bar
  filled=$((percent / 10))
  empty=$((10 - filled))
  bar=$(printf '█%.0s' $(seq 1 $filled))
  pad=$(printf '░%.0s' $(seq 1 $empty))
  ascii_bar="[$bar$pad]"

  # Icon
  icon="󰛨"

  # Color thresholds
  if [ "$percent" -lt 20 ]; then
      fg="#bf616a"  # red
  elif [ "$percent" -lt 55 ]; then
      fg="#fab387"  # orange
  else
      fg="#56b6c2"  # cyan
  fi

  # Device name
  device=$(brightnessctl --machine-readable | awk -F, 'NR==1 {print $1}')

  # Tooltip text
  tooltip="Brightness: $percent%\nDevice: $device"

  # JSON output
  echo "{\"text\":\"<span foreground='$fg'>$icon $ascii_bar $percent%</span>\",\"tooltip\":\"$tooltip\"}"
}

# Emit once on startup
emit

# Then only on changes
inotifywait -m -e modify "$BRIGHTNESS_FILE" --format '' 2>/dev/null | while read -r; do
  emit
done
