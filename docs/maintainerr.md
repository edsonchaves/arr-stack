# Maintainerr Setup

**URL:** `http://localhost:6246`

1. Settings → connect to Jellyfin (`http://jellyfin:8096`), Sonarr (`http://sonarr:8989`), Radarr (`http://radarr:7878`) with their API keys
2. Create rules — e.g. "delete movies that have been watched and have no pending requests after 30 days"
3. Rules run on a schedule and remove matching media from Jellyfin + send delete request to Radarr
