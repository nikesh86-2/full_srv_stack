#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Music Tidy + Duplicate Handler (Daily Run Version)
# ----------------------------
export PATH="/home/homeassistant/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TMPDIR="/mnt/backups/tmp"

WATCH_DIRS=(
  "/home/homeassistant/MusicDL/soulseek/downloads"
  "/home/homeassistant/MusicDL/torrents/lidarr"
)

LOG_FILE="/home/homeassistant/music-watcher.log"
STATE_DIR="/home/homeassistant/.cache/beets-watcher"
LOCK_FILE="$STATE_DIR/beets_import.lock"
STATE_FILE="$STATE_DIR/imported.txt"
TRASH_DIR="/home/homeassistant/MusicDL/removed"
FAILED_DIR="/home/homeassistant/MusicDL/failed-imports"

mkdir -p "$TRASH_DIR" "$FAILED_DIR" "$STATE_DIR"
touch "$LOG_FILE" "$STATE_FILE" "$LOCK_FILE"

log() {
    printf '%s | %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

should_ignore() {
    [[ "$1" =~ (/(lidarr-config|radarr-config|sonarr-config|jellyfin|failed|failed_imports|failed-imports|incomplete|partial|temp|_unpack|removed|trash|tv|movies|Audiobooks)/|/\.) ]] && return 0
    return 1
}

dir_has_audio() {
    local d="$1"
    find "$d" -maxdepth 2 -type f \
        \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \) \
        -print -quit | grep -q .
}

wait_for_settle() {
    local dir="$1"
    local size1=0 size2=0
    local attempt=0 max_attempts=5

    [[ -d "$dir" ]] || return 1

    while [ $attempt -lt $max_attempts ]; do
        size1=$(du -s -- "$dir" 2>/dev/null | awk '{print $1}' || echo 0)
        sleep 5
        size2=$(du -s -- "$dir" 2>/dev/null | awk '{print $1}' || echo 0)

        if [ "$size1" -eq "$size2" ]; then
            if ! lsof +D "$dir" >/dev/null 2>&1; then
                return 0
            fi
            log "   [Settle] Folder $dir is stable but in use."
        else
            log "   [Settle] Folder $dir is still changing size..."
        fi
        attempt=$((attempt + 1))
    done

    log "   [Timeout] Skipping $dir - busy/changing too long."
    return 1
}

move_to_removed() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    local dest="$TRASH_DIR/$(basename "$dir")_$(date +%Y%m%d_%H%M%S)"
    mv "$dir" "$dest"
    log "   [Cleanup] Moved to trash: $dest"
}

move_to_failed() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    local dest="$FAILED_DIR/$(basename "$dir")_$(date +%Y%m%d_%H%M%S)"
    mv "$dir" "$dest"
    log "   [Cleanup] Moved to failed: $dest"
}

handle_duplicates() {
    (
        flock -x 200
        log ">>> Starting Quality-Based Duplicate Check..."

        beet update >> "$LOG_FILE" 2>&1 || true

        # Find duplicate albums by MBID
        beet duplicates -M -a -f '$mb_albumid' | sort | uniq -d | while read -r MBID; do

            log "   [Duplicate] Checking MBID: $MBID"

            # Get album IDs
            mapfile -t ALBUM_IDS < <(beet ls -a -f '$id' "mb_albumid:$MBID")

            BEST_ID=""
            BEST_SIZE=0

            for AID in "${ALBUM_IDS[@]}"; do
                SIZE=$(beet ls -a -f '$filesize' "id:$AID" | awk '{s+=$1} END {print s}')
                if [[ "$SIZE" -gt "$BEST_SIZE" ]]; then
                    BEST_SIZE="$SIZE"
                    BEST_ID="$AID"
                fi
            done

            for AID in "${ALBUM_IDS[@]}"; do
                if [[ "$AID" != "$BEST_ID" ]]; then
                    log "      Removing inferior album ID $AID"
                    beet remove -a -d "id:$AID" >> "$LOG_FILE" 2>&1 || true
                fi
            done

        done

        log ">>> Quality-Based Duplicate Check Finished."
    ) 200>"$LOCK_FILE"
}


import_dir() {
    local dir="$1"

    if grep -qxF "$dir" "$STATE_FILE" 2>/dev/null; then
        return 0
    fi

    if should_ignore "$dir"; then
        log "   [Ignore] Skipping directory: $dir"
        return 0
    fi

    if ! dir_has_audio "$dir"; then
        return 0
    fi

    (
        flock -x 200 || exit 1
        log ">>> Importing: $dir"
        if timeout 30m beet import -q "$dir" >> "$LOG_FILE" 2>&1; then
            log "   [Success] $dir imported."
            echo "$dir" >> "$STATE_FILE"
            move_to_removed "$dir"
        else
            local rc=$?
            log "   [Error] Import failed or timed out (rc=$rc) for: $dir"
            echo "$dir" >> "$STATE_FILE"
            move_to_failed "$dir"
        fi
    ) 200>"$LOCK_FILE"
}

# ----------------------------
# EXECUTION SEQUENCE
# ----------------------------

log "--- Music Watcher Starting ---"

# 1) Clean old trash
log "Cleaning trash older than 20 days..."
find "$TRASH_DIR" -mindepth 1 -mtime +20 -exec rm -rf {} \; >/dev/null 2>&1 || true
find "$FAILED_DIR" -mindepth 1 -mtime +60 -exec rm -rf {} \; >/dev/null 2>&1 || true

# 2) Scan watch directories
for ROOT in "${WATCH_DIRS[@]}"; do
    [[ -d "$ROOT" ]] || { log "Warning: $ROOT does not exist."; continue; }
    log "Scanning: $ROOT"

    find "$ROOT" -type f \( \
        -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \
        -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' -o -iname '*.ape' \
    \) -printf '%h\n' | sort -u | while read -r DIR; do
        log "Found audio: $DIR"
        wait_for_settle "$DIR" && import_dir "$DIR"
    done
done

# 3) Cleanup duplicates
handle_duplicates

log "--- Music Watcher Complete ---"
exit 0
