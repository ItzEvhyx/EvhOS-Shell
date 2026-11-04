#!/usr/bin/env bash

TMP_IMG="/tmp/ocr-capture.png"

# Let user drag-select a region, same as your screenshot tool
grim -g "$(slurp)" "$TMP_IMG"

if [ ! -s "$TMP_IMG" ]; then
    notify-send "OCR" "No region selected"
    exit 1
fi

# Run OCR on the captured region
TEXT=$(tesseract "$TMP_IMG" stdout 2>/dev/null | sed '/^\s*$/d')

if [ -z "$TEXT" ]; then
    notify-send "OCR" "No text found"
    rm -f "$TMP_IMG"
    exit 1
fi

# Copy to clipboard
echo -n "$TEXT" | wl-copy

# Truncate long text for the notification body so it doesn't overflow
PREVIEW=$(echo "$TEXT" | head -c 200)
if [ ${#TEXT} -gt 200 ]; then
    PREVIEW="$PREVIEW..."
fi

notify-send "Text extracted:" "$PREVIEW"

rm -f "$TMP_IMG"
