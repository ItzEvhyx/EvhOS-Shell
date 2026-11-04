#!/usr/bin/env bash

WATCH_DIR="$HOME/Downloads"

inotifywait -m -e close_write --format "%f" "$WATCH_DIR" | while read -r FILE; do
    if [[ "$FILE" == *.zip ]]; then
        FULL_PATH="$WATCH_DIR/$FILE"
        FOLDER_NAME="${FILE%.zip}"
        DEST="$WATCH_DIR/$FOLDER_NAME"

        # Wait briefly to make sure the file finished writing fully
        sleep 1

        mkdir -p "$DEST"
        unzip -o "$FULL_PATH" -d "$DEST" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            notify-send "Auto-Extract" "Extracted: $FOLDER_NAME"
        else
            notify-send "Auto-Extract" "Failed to extract: $FILE"
        fi
    fi
done
