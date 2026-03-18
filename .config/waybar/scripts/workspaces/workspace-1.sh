#!/bin/bash
# workspace-1.sh — highlight workspace 1 if active (event-driven)

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

emit() {
  active=$(hyprctl activeworkspace -j | jq '.id')
  if [ "$active" -eq 1 ]; then
    echo " [ <span foreground='#fab387'>١</span> ] "
  else
    echo " [ ١ ] "
  fi
}

emit

nc -U "$SOCKET" 2>/dev/null | grep --line-buffered "^workspace>>\|^focusedmon>>" | while read -r; do
  emit
done
