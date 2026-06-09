#!/usr/bin/env bash
#
# Add a TV series to Pinchflat — one source per season playlist — using the
# exact field combo we proved out in practice (output_path_template_override
# with hardcoded season, fast_index off, media_playlist_index for episode #).
#
# Pinchflat has no JSON API; this script submits the HTML form endpoint with
# the CSRF token scraped from <meta name="csrf-token">.
#
# Usage:
#   ./pinchflat-add-series.sh "<TVDB title>" [media_profile_id]
#
# Reads "<season> <playlist_url>" lines from stdin until EOF.
#
# Examples:
#   ./pinchflat-add-series.sh "Bluey" <<EOF
#   1 https://www.youtube.com/playlist?list=PL...
#   2 https://www.youtube.com/playlist?list=PL...
#   EOF
#
#   ./pinchflat-add-series.sh "Pokémon" 2 < pokemon-seasons.txt
#
# Env overrides:
#   PINCHFLAT_URL   — default http://localhost:8945
#   PROFILE_ID      — default 2 (override the second arg)
#   FORCE_INDEX     — default true ("false" to skip post-create indexing)

set -euo pipefail

TITLE="${1:-}"
PROFILE_ID="${2:-${PROFILE_ID:-2}}"
URL="${PINCHFLAT_URL:-http://localhost:8945}"
DO_INDEX="${FORCE_INDEX:-true}"

if [[ -z "$TITLE" ]]; then
  echo "Usage: $0 \"<TVDB title>\" [media_profile_id]" >&2
  echo "  (reads \"<season> <playlist_url>\" lines from stdin)" >&2
  exit 1
fi

if ! curl -sf "$URL/healthcheck" >/dev/null; then
  echo "ERROR: Pinchflat not reachable at $URL" >&2
  exit 1
fi

JAR="$(mktemp)"
trap 'rm -f "$JAR" /tmp/pf-add-*.html' EXIT

csrf_from_page() {
  local path="$1"
  curl -sc "$JAR" -b "$JAR" "$URL$path" -o /tmp/pf-add-page.html
  grep -oE 'name="csrf-token" content="[^"]+"' /tmp/pf-add-page.html \
    | sed 's/.*content="//;s/"//' | head -1
}

create_source() {
  local season_num="$1" playlist_url="$2"
  local ss; ss=$(printf "%02d" "$season_num")
  local override="/shows/${TITLE}/Season ${ss}/S${ss}E{{ media_playlist_index }} - {{ title }}.{{ ext }}"

  local csrf; csrf=$(csrf_from_page "/sources/new")
  local response; response=$(curl -s -b "$JAR" -c "$JAR" \
    -H "X-CSRF-Token: $csrf" \
    -o /dev/null -w "%{http_code} %{redirect_url}" \
    -X POST "$URL/sources" \
    --data-urlencode "_csrf_token=$csrf" \
    --data-urlencode "source[original_url]=$playlist_url" \
    --data-urlencode "source[custom_name]=$TITLE" \
    --data-urlencode "source[media_profile_id]=$PROFILE_ID" \
    --data-urlencode "source[fast_index]=false" \
    --data-urlencode "source[download_media]=true" \
    --data-urlencode "source[output_path_template_override]=$override")

  local code id
  code=$(awk '{print $1}' <<<"$response")
  id=$(awk '{print $2}' <<<"$response" | grep -oE '/sources/[0-9]+' | grep -oE '[0-9]+$' || true)

  if [[ "$code" != "302" || -z "$id" ]]; then
    echo "  FAIL (HTTP $code) — $playlist_url" >&2
    return 1
  fi
  echo "$id"
}

force_index() {
  local source_id="$1"
  local csrf; csrf=$(csrf_from_page "/sources/$source_id")
  curl -s -b "$JAR" -c "$JAR" \
    -H "X-CSRF-Token: $csrf" \
    -o /dev/null -w "  force_index source $source_id → %{http_code}\n" \
    -X POST "$URL/sources/$source_id/force_index" \
    --data-urlencode "_csrf_token=$csrf"
}

echo "Adding series: $TITLE  (profile $PROFILE_ID, $URL)"
created_ids=()

while read -r season url; do
  [[ -z "$season" || "$season" =~ ^# ]] && continue
  if [[ -z "$url" ]]; then
    echo "  SKIP (bad line: \"$season\")" >&2
    continue
  fi
  ss=$(printf "%02d" "$season")
  echo "  Season $ss → $url"
  if id=$(create_source "$season" "$url"); then
    echo "    created source $id"
    created_ids+=("$id")
  fi
done

if [[ ${#created_ids[@]} -eq 0 ]]; then
  echo "Nothing created." >&2
  exit 1
fi

if [[ "$DO_INDEX" == "true" ]]; then
  echo "Triggering slow index on ${#created_ids[@]} source(s)..."
  for id in "${created_ids[@]}"; do force_index "$id"; done
fi

echo
echo "Done. ${#created_ids[@]} source(s) created for \"$TITLE\":"
for id in "${created_ids[@]}"; do echo "  $URL/sources/$id"; done
echo
echo "Next: watch downloads start in the UI, or:"
echo "  find /mnt/data/media/youtube-shows/shows/$TITLE -name '*.mp4' | wc -l"
