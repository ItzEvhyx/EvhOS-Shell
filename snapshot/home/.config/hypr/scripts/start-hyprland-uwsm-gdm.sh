#!/usr/bin/env bash
# GDM: clear leftover UWSM state, then start Hyprland via UWSM.
# Uses /usr/bin/start-hyprland directly so we never re-enter this wrapper
# as the compositor command (that caused the login freeze loop).
set -euo pipefail
"$HOME/.config/hypr/scripts/ensure-clean-graphical-session.sh" || true
exec uwsm start -e -D Hyprland /usr/bin/start-hyprland "$@"
