#!/bin/bash
# ── wg-status.sh ───────────────────────────────────────────
# Description: Checks if WireGuard VPN is active
# Usage: Called by Waybar `custom/vpn` every 5s
# Output: Pango markup → [شبح]: Country or KAPUTT
# ───────────────────────────────────────────────────────────
STATE_FILE="/tmp/vpn-state"
prev_state=$(cat "$STATE_FILE" 2>/dev/null)

if ip a | grep -q "wg0"; then
  country=$(curl -s --max-time 3 'http://ip-api.com/line/?fields=country' 2>/dev/null)
  country="${country^^}"
  # Guard against HTML responses (e.g. Cloudflare challenge pages)
  if [[ -z "$country" || "$country" == *"<"* || ${#country} -gt 50 ]]; then
    country="UNKNOWN"
  fi
  if [[ "$prev_state" != "up" ]]; then
    notify-send -u normal "شبح VPN" "Connected — $country"
    echo "up" > "$STATE_FILE"
  fi
  echo "<span foreground='#fab387'>[شبح]: $country</span>"
else
  if [[ "$prev_state" != "down" ]]; then
    notify-send -u critical "شبح VPN" "Disconnected"
    echo "down" > "$STATE_FILE"
  fi
  echo "<span foreground='#bf616a'>[شبح]: KAPUTT</span>"
fi