#!/bin/bash
# workspace-slot-1 — shows workspace 1 (eDP-1) or 5 (DP-1) based on focused monitor

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

LABELS_EDP=(١ ٢ ٣ ٤ ٥)
LABELS_DP=(٦ ٧ ٨ ٩ ٠)
SLOT=0  # 0-indexed

get_ws() {
  local mon
  mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
  if [[ "$mon" == "DP-1" ]]; then
    echo $((SLOT + 6))
  else
    echo $((SLOT + 1))
  fi
}

get_label() {
  local mon
  mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
  if [[ "$mon" == "DP-1" ]]; then
    echo "${LABELS_DP[$SLOT]}"
  else
    echo "${LABELS_EDP[$SLOT]}"
  fi
}

emit() {
  local ws label active special
  ws=$(get_ws)
  label=$(get_label)
  active=$(hyprctl activeworkspace -j | jq '.id')
  special=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .specialWorkspace.name')
  if [ -n "$special" ] || [ "$active" -eq "$ws" ]; then
    echo " [ <span foreground='#fab387'>$label</span> ] "
  else
    echo " [ $label ] "
  fi
}

emit

nc -U "$SOCKET" 2>/dev/null | grep --line-buffered "^workspace>>\|^focusedmon>>\|^activespecial>>" | while read -r; do
  emit
done
