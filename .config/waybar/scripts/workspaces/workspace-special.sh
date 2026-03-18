#!/bin/bash
# workspace-special.sh — highlight special workspace if active (event-driven)

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

emit() {
  active_ws=$(hyprctl activewindow -j | jq -r '.workspace.name')
  if [[ "$active_ws" == "special:magic" ]]; then
    echo " <span foreground='#fab387'>✶</span> "
  else
    echo " ✶ "
  fi
}

emit

nc -U "$SOCKET" 2>/dev/null | grep --line-buffered "^workspace>>\|^focusedmon>>\|^activespecial>>" | while read -r; do
  emit
done
