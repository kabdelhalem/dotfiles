#!/bin/bash
# workspace-8.sh — highlight workspace 8 if active (event-driven)

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

emit() {
  active=$(hyprctl activeworkspace -j | jq '.id')
  if [ "$active" -eq 8 ]; then
    echo " [ <span foreground='#fab387'>٨</span> ] "
  else
    echo " [ ٨ ] "
  fi
}

emit

nc -U "$SOCKET" 2>/dev/null | grep --line-buffered "^workspace>>\|^focusedmon>>" | while read -r; do
  emit
done
