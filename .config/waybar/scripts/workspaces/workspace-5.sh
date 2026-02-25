#!/bin/bash
# workspace-5.sh — highlight workspace 5 if active

active=$(hyprctl activeworkspace -j | jq '.id')

if [ "$active" -eq 5 ]; then
  echo " [ <span foreground='#fab387'>٥</span> ] "
else
  echo " [ ٥ ] "
fi

