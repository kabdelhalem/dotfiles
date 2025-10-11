#!/bin/bash
# workspace-special.sh — highlight special workspace if active

active_ws=$(hyprctl activewindow -j | jq -r '.workspace.name')

if [[ "$active_ws" == "special:magic" ]]; then
  echo " <span foreground='#fab387'>✶</span> "
else
  echo " ✶ "
fi
