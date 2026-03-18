#!/bin/bash
# workspace-click.sh <slot> — dispatches to the correct workspace based on focused monitor
# slot is 0-indexed

SLOT=$1
mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')

if [[ "$mon" == "DP-1" ]]; then
  ws=$((SLOT + 6))
else
  ws=$((SLOT + 1))
fi

hyprctl dispatch workspace "$ws"
