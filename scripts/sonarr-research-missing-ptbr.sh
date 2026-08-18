#!/usr/bin/env bash
# Re-search Sonarr episodes that still lack PT-BR subtitles.
#
# Bazarr keeps retrying subtitle *providers* on its own, but Sonarr never
# re-searches indexers for an already-downloaded episode, so an English-only
# fansub grab (Asakura/SubsPlease/etc.) is never upgraded to a later
# ToonsHub/CR "Multi-Subs" release that ships PT-BR embedded.
#
# This script bridges the two: every episode still on Bazarr's PT-BR wanted
# list that aired recently gets a Sonarr automatic search. Sonarr only grabs
# a replacement when the new release scores higher (Subs PT-BR +1000,
# Multi-Subs +200), so this is upgrade-only and self-terminating: once a
# PT-BR sub exists (embedded or downloaded), the episode leaves the wanted
# list and is no longer searched.
#
# Runs from cron; see crontab. Requires: curl, python3.
set -euo pipefail

NAS_DIR="/home/edson/nas-server"
SONARR_URL="http://localhost:8989"
BAZARR_URL="http://localhost:6767"
export MAX_AGE_DAYS=45   # only re-search episodes that aired recently; old backlog rarely gets new releases
export MAX_EPISODES=20   # per run, to be gentle on indexers

export SONARR_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' "$NAS_DIR/config/sonarr/config.xml")
BAZARR_KEY=$(grep -oP '(?<=apikey: )\S+' "$NAS_DIR/config/bazarr/config/config.yaml" | head -1)

exec 9>/tmp/sonarr-research-ptbr.lock
flock -n 9 || exit 0

export WANTED=$(curl -sf -H "X-API-KEY: $BAZARR_KEY" "$BAZARR_URL/api/episodes/wanted?length=500")
export SONARR_URL

EPISODE_IDS=$(python3 <<'EOF'
import json, os, urllib.request
from datetime import datetime, timezone, timedelta

wanted = json.loads(os.environ["WANTED"])["data"]
cutoff = datetime.now(timezone.utc) - timedelta(days=int(os.environ["MAX_AGE_DAYS"]))
sonarr = os.environ["SONARR_URL"]

ids = []
for ep in wanted:
    if not any(m["code2"] == "pb" for m in ep["missing_subtitles"]):
        continue
    req = urllib.request.Request(
        f"{sonarr}/api/v3/episode/{ep['sonarrEpisodeId']}",
        headers={"X-Api-Key": os.environ["SONARR_KEY"]})
    try:
        info = json.load(urllib.request.urlopen(req, timeout=10))
    except Exception:
        continue
    air = info.get("airDateUtc")
    if not air:
        continue
    aired = datetime.fromisoformat(air.replace("Z", "+00:00"))
    if aired >= cutoff:
        ids.append(ep["sonarrEpisodeId"])

print(json.dumps(ids[:int(os.environ["MAX_EPISODES"])]))
EOF
)

COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$EPISODE_IDS")
if [ "$COUNT" -eq 0 ]; then
    echo "$(date -Is) nothing to search" >> "$NAS_DIR/logs/sonarr-research-ptbr.log"
    exit 0
fi

curl -sf -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
    -d "{\"name\":\"EpisodeSearch\",\"episodeIds\":$EPISODE_IDS}" \
    "$SONARR_URL/api/v3/command" > /dev/null

echo "$(date -Is) searched $COUNT episodes: $EPISODE_IDS" >> "$NAS_DIR/logs/sonarr-research-ptbr.log"
