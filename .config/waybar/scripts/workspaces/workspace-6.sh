#!/bin/bash
# workspace-6.sh — highlight workspace 6 if active (event-driven)

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

emit() {
  active=$(hyprctl activeworkspace -j | jq '.id')
  if [ "$active" -eq 6 ]; then
    echo " [ <span foreground='#fab387'>٦</span> ] "
  else
    echo " [ ٦ ] "
  fi
}

emit

nc -U "$SOCKET" 2>/dev/null | grep --line-buffered "^workspace>>\|^focusedmon>>" | while read -r; do
  emit
done
