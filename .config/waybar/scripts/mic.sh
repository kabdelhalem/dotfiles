#!/bin/bash
# ── mic.sh ─────────────────────────────────────────────────
# Description: Shows microphone mute/unmute status with icon
# Usage: Waybar `custom/microphone` (event-driven, no polling)
# Dependencies: pactl (PulseAudio / PipeWire)
# ───────────────────────────────────────────────────────────

emit() {
  if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q 'yes'; then
    echo "<span foreground='#fab387'>[    ]</span>"
  else
    echo "<span foreground='#56b6c2'>[    ]</span>"
  fi
}

# Emit once on startup
emit

# Re-emit on any source change (mute toggle, default source switch)
pactl subscribe 2>/dev/null | grep --line-buffered -E "'change' on source|'new' on source|'remove' on source" | while read -r; do
  emit
done
