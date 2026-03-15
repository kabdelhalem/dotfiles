#!/bin/bash
# ── wg-status.sh ───────────────────────────────────────────
# Description: Checks if WireGuard VPN is active
# Usage: Called by Waybar `custom/vpn` every 5s
# Output: Pango markup → [شبح]: Country or KAPUTT
# ───────────────────────────────────────────────────────────
if ip a | grep -q "wg0"; then
  country=$(curl -s --max-time 3 'http://ip-api.com/line/?fields=country' 2>/dev/null)
  country="${country^^}"
  # Guard against HTML responses (e.g. Cloudflare challenge pages)
  if [[ -z "$country" || "$country" == *"<"* || ${#country} -gt 50 ]]; then
    country="UNKNOWN"
  fi
  echo "<span foreground='#fab387'>[شبح]: $country</span>"
else
  echo "<span foreground='#bf616a'>[شبح]: KAPUTT</span>"
fi