#!/bin/bash

updates=""
count=0

# Check pacman + AUR updates via yay
if command -v yay &>/dev/null; then
    yay_updates=$(yay -Qu 2>/dev/null)
    if [[ -n "$yay_updates" ]]; then
        yay_count=$(echo "$yay_updates" | wc -l)
        count=$((count + yay_count))
        updates+="$yay_count pacman/AUR"
    fi
elif command -v checkupdates &>/dev/null; then
    pacman_updates=$(checkupdates 2>/dev/null)
    if [[ -n "$pacman_updates" ]]; then
        pac_count=$(echo "$pacman_updates" | wc -l)
        count=$((count + pac_count))
        updates+="$pac_count pacman"
    fi
fi

# Check snap updates
if command -v snap &>/dev/null; then
    snap_updates=$(snap refresh --list 2>/dev/null | tail -n +2)
    if [[ -n "$snap_updates" ]]; then
        snap_count=$(echo "$snap_updates" | wc -l)
        count=$((count + snap_count))
        [[ -n "$updates" ]] && updates+=", "
        updates+="$snap_count snap"
    fi
fi

# Send notification if updates are available
if [[ $count -gt 0 ]]; then
    notify-send -u normal -a "Update Check" \
        "Updates available ($count)" \
        "$updates packages can be updated"
fi
