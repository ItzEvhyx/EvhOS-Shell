#!/bin/sh
# Runs independently of the installed Serpantinum files, including after upgrades.
lock="${XDG_RUNTIME_DIR:-/tmp}/serp-customizations-${UID:-$(id -u)}.lock"
exec 9>"$lock"
flock -n 9 || exit 0
changed=0
failed=0
shell_qml="$HOME/.local/share/serpantinum/src/quickshell/Shell.qml"
reload_pending="${XDG_RUNTIME_DIR:-/tmp}/serp-customizations-reload-${UID:-$(id -u)}"
for script in "$HOME/.config/hypr/scripts/restore-screenshot-preview.py" "$HOME/.config/hypr/scripts/restore-serp-mascot.py" "$HOME/.config/hypr/scripts/restore-serp-dock.py" "$HOME/.config/hypr/scripts/restore-serp-pill-style.py" "$HOME/.config/hypr/scripts/restore-serp-glass.py" "$HOME/.config/hypr/scripts/restore-serp-icons.py" "$HOME/.config/hypr/scripts/restore-serp-launcher-spacing.py" "$HOME/.config/hypr/scripts/restore-serp-volume-position.py" "$HOME/.config/hypr/scripts/restore-serp-network-position.py" "$HOME/.config/hypr/scripts/restore-serp-media-position.py" "$HOME/.config/hypr/scripts/restore-serp-notch.py" "$HOME/.config/hypr/scripts/restore-serp-notch-outline.py" "$HOME/.config/hypr/scripts/restore-serp-notch-hover.py" "$HOME/.config/hypr/scripts/restore-serp-media-visualizer.py" "$HOME/.config/hypr/scripts/restore-serp-dock-indicators.py" "$HOME/.config/hypr/scripts/restore-serp-calendar.py"; do
    "$script"
    status=$?
    case "$status" in
        0) ;;
        10) changed=1 ;;
        *) failed=1 ;;
    esac
done
if [ "$changed" -eq 1 ]; then touch "$reload_pending"; fi
if [ -f "$reload_pending" ] && [ "$(cat "$HOME/.local/state/active-shell" 2>/dev/null)" = serpantinum ]; then
    if bash "$HOME/.local/share/serpantinum/src/scripts/reload.sh" >/dev/null 2>&1; then rm -f "$reload_pending"; fi
fi
exit "$failed"
