#!/bin/bash
# ── volume.sh ─────────────────────────────────────────────
# Description: Shows current audio volume with ASCII bar + tooltip
# Usage: Waybar `custom/volume` every 1s
# Dependencies: wpctl, awk, bc, seq, printf
# ───────────────────────────────────────────────────────────

# Get raw volume and convert to int
vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ print $2 }')
vol_int=$(echo "$vol_raw * 100" | bc 2>/dev/null | awk '{ print int($1) }' 2>/dev/null)

# Handle empty or invalid volume
if [ -z "$vol_int" ] || [ "$vol_int" = "0" ] && [ -z "$vol_raw" ]; then
  vol_int=0
fi

# Ensure vol_int is a valid number
if ! [[ "$vol_int" =~ ^[0-9]+$ ]]; then
  vol_int=0
fi

# Check mute status
is_muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo true || echo false)

# Get default sink description (human-readable)
sink=$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep '\*' | cut -d'.' -f2- | sed 's/^\s*//; s/\[.*//')

# Icon logic
if [ "$is_muted" = true ]; then
  icon="🔇"
  vol_int=0
elif [ "$vol_int" -lt 50 ]; then
  icon="🔉"
else
  icon="🔊"
fi

# ASCII bar
filled=$((vol_int / 10))
empty=$((10 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled))
pad=$(printf '░%.0s' $(seq 1 $empty))
ascii_bar="[$bar$pad]"

# Color logic
if [ "$is_muted" = true ] || [ "$vol_int" -lt 10 ]; then
  fg="#bf616a" # red
elif [ "$vol_int" -lt 50 ]; then
  fg="#fab387" # orange
else
  fg="#56b6c2" # cyan
fi

# Tooltip text
if [ "$is_muted" = true ]; then
  tooltip="Audio: Muted\nOutput: $sink"
else
  tooltip="Audio: $vol_int%\nOutput: $sink"
fi

# Final JSON output
echo "{\"text\":\"<span foreground='$fg'>$icon $ascii_bar $vol_int%</span>\",\"tooltip\":\"$tooltip\"}"