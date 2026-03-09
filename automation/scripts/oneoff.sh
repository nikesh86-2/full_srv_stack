#!/usr/bin/env bash
set -euo pipefail

WATCH_FOLDER="/home/homeassistant/MusicDL/torrents"
DEST_FOLDER="/mnt/nas/Music"
CACHE_DIR="/home/homeassistant/.cache/music-check"

DEST_MD5_CACHE="$CACHE_DIR/dest_md5.txt"
LIB_MD5="$CACHE_DIR/lib_md5.txt"

mkdir -p "$CACHE_DIR"

echo "--------------------------------------------------"
echo "--- Music Library Verification Starting ---"
echo "--------------------------------------------------"

############################################
# 1️⃣ Cache Beets Library MD5s
############################################

echo "Caching Beets library MD5s..."
beet ls -f '$md5' | sort > "$LIB_MD5"
echo "Library contains $(wc -l < "$LIB_MD5") files."
echo

############################################
# 2️⃣ Cache Destination Folder MD5s
############################################

if [[ -f "$DEST_MD5_CACHE" ]]; then
    echo "Using cached destination MD5 list."
else
    echo "Calculating MD5s for destination folder..."
    echo "This may take a while on large NAS drives."
    echo

    if command -v pv >/dev/null 2>&1; then
        TOTAL_DEST=$(find "$DEST_FOLDER" -type f \( \
            -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \
            -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \
        \) | wc -l)

        find "$DEST_FOLDER" -type f \( \
            -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \
            -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \
        \) -print0 | \
        pv -0 -l -s "$TOTAL_DEST" -N "Scanning destination" | \
        xargs -0 md5sum | \
        awk '{print $1}' | sort > "$DEST_MD5_CACHE"
    else
        find "$DEST_FOLDER" -type f \( \
            -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \
            -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \
        \) -exec md5sum {} \; | \
        awk '{print $1}' | sort > "$DEST_MD5_CACHE"
    fi

    echo
    echo "Destination contains $(wc -l < "$DEST_MD5_CACHE") files."
fi

echo

############################################
# 3️⃣ Check Each Subfolder
############################################

echo "Checking subfolders in:"
echo "$WATCH_FOLDER"
echo

find "$WATCH_FOLDER" -mindepth 1 -maxdepth 1 -type d | while read -r SUBFOLDER; do

    mapfile -d '' FILE_ARRAY < <(
        find "$SUBFOLDER" -type f \( \
            -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \
            -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \
        \) -print0
    )

    TOTAL=${#FILE_ARRAY[@]}

    if [[ $TOTAL -eq 0 ]]; then
        echo "[$(basename "$SUBFOLDER")] No audio files found."
        echo
        continue
    fi

    echo "[$(basename "$SUBFOLDER")] Checking $TOTAL files..."

    MISSING_FILES=()

    if command -v pv >/dev/null 2>&1; then
        printf '%s\0' "${FILE_ARRAY[@]}" | \
        pv -0 -l -s "$TOTAL" -N "Checking files" | \
        while IFS= read -r -d '' FILE; do
            HASH=$(md5sum "$FILE" | awk '{print $1}')
            if ! grep -qx "$HASH" "$LIB_MD5" && ! grep -qx "$HASH" "$DEST_MD5_CACHE"; then
                echo "$FILE" >> "$CACHE_DIR/.missing_tmp"
            fi
        done

        if [[ -f "$CACHE_DIR/.missing_tmp" ]]; then
            mapfile -t MISSING_FILES < "$CACHE_DIR/.missing_tmp"
            rm "$CACHE_DIR/.missing_tmp"
        fi
    else
        for FILE in "${FILE_ARRAY[@]}"; do
            HASH=$(md5sum "$FILE" | awk '{print $1}')
            if ! grep -qx "$HASH" "$LIB_MD5" && ! grep -qx "$HASH" "$DEST_MD5_CACHE"; then
                MISSING_FILES+=("$FILE")
            fi
        done
    fi

    if [[ ${#MISSING_FILES[@]} -eq 0 ]]; then
        echo "[$(basename "$SUBFOLDER")] All $TOTAL files imported ✅"
    else
        echo "[$(basename "$SUBFOLDER")] ${#MISSING_FILES[@]} of $TOTAL files missing ❌"
        for F in "${MISSING_FILES[@]}"; do
            echo "   ❌ $F"
        done
    fi

    echo
done

echo "--------------------------------------------------"
echo "--- Music Library Verification Complete ---"
echo "--------------------------------------------------"
