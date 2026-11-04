#!/bin/sh
if [ "$1" = "region" ]; then
    geom=$(slurp) || exit 0
    grim -g "$geom" - | wl-copy
    exit 0
fi

# Serpantinum updates replace its notification component. Reapply the local
# thumbnail before the next full screenshot, then reload the running shell.
"$HOME/.config/hypr/scripts/restore-screenshot-preview.py"
preview_status=$?
if [ "$preview_status" -eq 10 ]; then
    bash "$HOME/.local/share/serpantinum/src/scripts/reload.sh" >/dev/null 2>&1 && sleep 2
elif [ "$preview_status" -ne 0 ]; then
    notify-send -a Screenshot "Screenshot preview needs attention" "The shell notification layout changed; the local preview could not be restored."
fi

dir="${XDG_RUNTIME_DIR:-/tmp}/screenshots"
mkdir -p "$dir"
find "$dir" -type f -mmin +1440 -delete

f="$dir/shot-$(date +%s).png"
grim "$f" || exit 1
wl-copy < "$f" || exit 1
notify-send -a Screenshot -i "$f" -h "string:image-path:$f" "Screenshot taken" "Copied to clipboard"
