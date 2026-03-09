#!/bin/bash

### --- SETTINGS ---

# qBittorrent
QBIT_USER="nikesh"
QBIT_PASS="m5kzdjxr"
QBIT_URL="http://localhost:8081"

# slskd
SLSKD_URL="http://localhost:5030"     # change if different
SLSKD_API_KEY="dILIUys8B0SX2zETmBHnpn50QdN1oXPK"
SLSKD_CONTAINER="slskd"
# Paths for slskd
CONF_DIR="/srv/media/media-stack/slskd-config"
ACTIVE_CONF="$CONF_DIR/slskd.yml"
SLOW_CONF="$CONF_DIR/slskd.slow.yml"
FAST_CONF="$CONF_DIR/slskd.fast.yml"

# Speed Profiles (KB/s)
# FAST
SLSKD_FAST_UPLOAD=0        # 0 = unlimited
SLSKD_FAST_DOWNLOAD=0

# SLOW
SLSKD_SLOW_UPLOAD=500      # 500 KB/s (~4 Mbps)
SLSKD_SLOW_DOWNLOAD=2000   # 2 MB/s (~16 Mbps)

COOKIE_FILE="/tmp/qbit_cookie.txt"

MODE="$1"

#############################################
# qBittorrent
#############################################

COOKIE_FILE="/tmp/qbit_cookie.txt"

# Login
LOGIN_RESPONSE=$(curl -s \
  --referer "$QBIT_URL" \
  --data "username=$QBIT_USER&password=$QBIT_PASS" \
  "$QBIT_URL/api/v2/auth/login" \
  -c "$COOKIE_FILE")

if [[ "$LOGIN_RESPONSE" != "Ok." ]]; then
  echo "qBittorrent login failed"
  rm -f "$COOKIE_FILE"
  exit 1
fi

# Toggle speed mode
curl -s \
  -b "$COOKIE_FILE" \
  -X POST \
  -d "value=$MODE" \
  "$QBIT_URL/api/v2/transfer/toggleSpeedLimitsMode"

rm -f "$COOKIE_FILE"

#############################################
# slskd - Transfer API Method
#############################################
if [ "$MODE" = "1" ]; then
    echo "Action: Throttling to SLOW mode..."
    # 2. Handle slskd via Config Swap
    cp "$SLOW_CONF" "$ACTIVE_CONF"
    docker restart "$SLSKD_CONTAINER"
    sleep 30
    curl -s -H "X-API-Key: $SLSKD_API_KEY" http://localhost:5030/api/v0/options | jq '.global | {upload: .upload.speedLimit, download: .download.speedLimit}'

else
    echo "Action: Restoring to FAST mode..."

    # 2. Handle slskd via Config Swap
    cp "$FAST_CONF" "$ACTIVE_CONF"
    docker restart "$SLSKD_CONTAINER"
    sleep 30
    curl -s -H "X-API-Key: $SLSKD_API_KEY" http://localhost:5030/api/v0/options | jq '.global | {upload: .upload.speedLimit, download: .download.speedLimit}'
    
fi

echo "Done. Configurations swapped and services refreshed."

exit 0


