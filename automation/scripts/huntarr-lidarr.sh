#!/usr/bin/env bash
# Huntarr-Lidarr Randomized Search (Pi-friendly)
# Randomizes missing album selection, stores a short history to avoid repeats,
# adds jittered sleep to avoid getting 'stuck', and is safe under systemd.

set -euo pipefail

: "${API_URL:?Set API_URL env var, e.g. http://192.168.0.48:8686}"
: "${API_KEY:?Set API_KEY env var}"

# --- Tunables ---
CHECK_OK_MIN=900     # 15 min min sleep after a search
CHECK_OK_MAX=1500    # up to ~25 min
CHECK_IDLE_MIN=1800  # 30 min min sleep when nothing found
CHECK_IDLE_MAX=3600  # up to 60 min

# Keep state under the service user’s home
STATE_DIR="${STATE_DIR:-/home/homeassistant/.cache/huntarr-lidarr}"
HISTORY_FILE="${HISTORY_FILE:-$STATE_DIR/history.txt}"
LOCK_FILE="${LOCK_FILE:-$STATE_DIR/lock}"
MAX_HISTORY="${MAX_HISTORY:-200}"

mkdir -p "$STATE_DIR"

rand_sleep() {
  local min_s="$1" max_s="$2"
  local span=$((max_s - min_s))
  local jitter=$((RANDOM % (span + 1)))
  local dur=$((min_s + jitter))
  echo "Sleeping ${dur}s..."
  sleep "${dur}"
}

add_to_history() {
  local id="$1"
  printf '%s\n' "$id" >> "$HISTORY_FILE"
  local lines
  lines="$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)"
  if [ "$lines" -gt "$MAX_HISTORY" ]; then
    tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
  fi
}

in_history() {
  local id="$1"
  [ -f "$HISTORY_FILE" ] && grep -qx "$id" "$HISTORY_FILE"
}

# Single-instance guard
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another instance is running. Exiting."
  exit 0
fi

echo "Starting Huntarr-Lidarr randomized scanner..."

while true; do
  echo "Querying Lidarr for missing albums (randomized)..."

  base_url="${API_URL%/}/api/v1/wanted/missing"
  headers=(-H "X-Api-Key: $API_KEY" -s)

  # Fetch meta to get totalRecords (cheap: pageSize=1)
  meta_json="$(curl "${headers[@]}" "$base_url?page=1&pageSize=1" || echo '{}')"
  total="$(printf '%s' "$meta_json" | jq -r '.totalRecords // 0')"

  if [ -z "${total:-}" ] || [ "$total" = "null" ] || [ "$total" -le 0 ]; then
    echo "No missing albums (totalRecords=${total:-0})."
    rand_sleep "$CHECK_IDLE_MIN" "$CHECK_IDLE_MAX"
    continue
  fi

  echo "Lidarr reports $total missing album(s)."

  picked_id=""
  attempts=0
  max_attempts=10

  while [ $attempts -lt $max_attempts ]; do
    attempts=$((attempts + 1))
    # Pick random 1-based page (pageSize=1 to keep payload tiny)
    rand_page=$(( (RANDOM % total) + 1 ))
    rec_json="$(curl "${headers[@]}" "$base_url?page=$rand_page&pageSize=1" || echo '{}')"
    candidate_id="$(printf '%s' "$rec_json" | jq -r '.records[0].id // empty')"
    if [ -n "$candidate_id" ]; then
      if ! in_history "$candidate_id"; then
        picked_id="$candidate_id"
        break
      else
        echo "ID $candidate_id was recently tried; retrying ($attempts/$max_attempts)..."
      fi
    else
      echo "Random page had no record; retrying ($attempts/$max_attempts)..."
    fi
  done

  if [ -z "$picked_id" ]; then
    echo "Couldn’t find a new ID after $max_attempts attempts, falling back to first record."
    picked_id="$(curl "${headers[@]}" "$base_url?page=1&pageSize=1" | jq -r '.records[0].id // empty')"
  fi

  if [ -z "$picked_id" ]; then
    echo "No album ID found. Will retry later."
    rand_sleep "$CHECK_IDLE_MIN" "$CHECK_IDLE_MAX"
    continue
  fi

  echo "Triggering AlbumSearch for ID $picked_id ..."
  curl -s -X POST \
    -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"AlbumSearch\",\"albumIds\":[${picked_id}]}" \
    "${API_URL%/}/api/v1/command" >/dev/null || true

  add_to_history "$picked_id"
  echo "Search sent for $picked_id."
  rand_sleep "$CHECK_OK_MIN" "$CHECK_OK_MAX"
done
