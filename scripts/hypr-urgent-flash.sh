#!/usr/bin/env bash
# hypr-urgent-flash.sh — mark windows that raise the urgency flag (e.g.
# alacritty bell from an unfocused Claude Code session) with a red border
# until they're focused.
#
# Works by toggling the "urgent" window tag; the matching windowrule in
# hyprland.conf ("urgent-border") paints tagged windows red:
#
#   windowrule {
#       name = urgent-border
#       match:tag = urgent
#       border_color = rgba(e06c75ff) rgba(e06c75ff)
#       border_size = 4
#   }
#
# Listens on Hyprland's socket2 event stream:
#   urgent>>ADDR          tag the window
#   activewindowv2>>ADDR  window focused -> untag it
#   closewindow>>ADDR     window gone -> forget it
#
# Started from hyprland.conf via exec-once. Exits when Hyprland does.

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
[[ -S "$sock" ]] || { echo "hypr-urgent-flash: no event socket" >&2; exit 1; }

# Single instance per Hyprland session.
exec 9>"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/urgent-flash.lock"
flock -n 9 || exit 0

declare -A tagged

untag() {
  local addr="$1"
  [[ -n "${tagged[$addr]}" ]] || return 0
  unset "tagged[$addr]"
  hyprctl -q dispatch tagwindow -- -urgent "address:0x$addr" 2>/dev/null
}

cleanup() {
  local addr j
  for addr in "${!tagged[@]}"; do untag "$addr"; done
  for j in $(jobs -p); do kill "$j" 2>/dev/null; done
}
trap cleanup EXIT INT TERM

# Process substitution (not a pipe) so the loop runs in the main shell and
# the tagged map stays visible to the EXIT trap.
while IFS= read -r line; do
  case "$line" in
    urgent\>\>*)
      addr="${line#urgent>>}"
      # Never mark the currently focused window.
      [[ "$(hyprctl activewindow -j 2>/dev/null | jq -r .address)" == "0x$addr" ]] && continue
      hyprctl -q dispatch tagwindow +urgent "address:0x$addr" 2>/dev/null
      tagged[$addr]=1
      ;;
    activewindowv2\>\>*)
      untag "${line#*>>}"
      ;;
    closewindow\>\>*)
      addr="${line#*>>}"
      unset "tagged[$addr]" 2>/dev/null
      ;;
  esac
done < <(nc -U "$sock" 9<&-) # close the lock fd so a lingering nc can't hold it
