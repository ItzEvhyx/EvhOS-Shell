#!/usr/bin/env bash
# Tear down a leftover graphical-session so UWSM/GDM can start Hyprland again.
# Safe no-op when a session is already starting or Hyprland is running.

set -u

log() {
    printf 'ensure-clean-graphical-session: %s\n' "$*" >&2
}

uid="${UID:-$(id -u)}"

hyprland_running() {
    pgrep -u "$uid" -x Hyprland >/dev/null 2>&1
}

# Never interfere with an in-progress UWSM compositor start
compositor_starting_or_up() {
    systemctl --user is-active --quiet 'wayland-wm@*.service' 2>/dev/null \
        || systemctl --user is-activating --quiet 'wayland-wm@*.service' 2>/dev/null \
        || systemctl --user is-active --quiet 'wayland-session@*.target' 2>/dev/null \
        || systemctl --user is-activating --quiet 'wayland-session@*.target' 2>/dev/null
}

graphical_active() {
    systemctl --user is-active --quiet graphical-session.target 2>/dev/null \
        || systemctl --user is-active --quiet graphical-session-pre.target 2>/dev/null
}

if hyprland_running; then
    exit 0
fi

if compositor_starting_or_up; then
    log "compositor unit already starting/active — skipping cleanup"
    exit 0
fi

if ! graphical_active \
    && ! systemctl --user is-failed --quiet 'wayland-wm@*.service' 2>/dev/null; then
    exit 0
fi

log "stale graphical session detected (Hyprland not running) — cleaning up"

systemctl --user start --job-mode=replace-irreversibly wayland-session-shutdown.target 2>/dev/null || true

systemctl --user stop --job-mode=replace-irreversibly \
    graphical-session.target \
    graphical-session-pre.target \
    xdg-desktop-autostart.target \
    2>/dev/null || true

systemctl --user stop \
    'wayland-wm@*.service' \
    'wayland-wm-env@*.service' \
    'wayland-session-bindpid@*.service' \
    xdg-desktop-portal-hyprland.service \
    xdg-desktop-portal-gtk.service \
    xdg-desktop-portal.service \
    2>/dev/null || true

systemctl --user reset-failed 2>/dev/null || true
sleep 0.3

if graphical_active; then
    log "warning: graphical-session.target still active after cleanup"
    exit 1
fi

log "cleanup complete"
exit 0
