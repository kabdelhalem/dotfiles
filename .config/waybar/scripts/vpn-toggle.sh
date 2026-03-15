#!/bin/bash
# ── vpn-toggle.sh ─────────────────────────────────────────
# Description: Toggle WireGuard VPN on/off
# Usage: Called by Waybar `custom/vpn` on click
# Dependencies: wg-quick, ip
# ──────────────────────────────────────────────────────────
if ip a | grep -q "wg0"; then
    sudo wg-quick down wg0
else
    sudo wg-quick up wg0
fi
pkill -SIGRTMIN+8 waybar