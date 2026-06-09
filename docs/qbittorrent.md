# qBittorrent Setup

**URL:** `http://localhost:8080`

The linuxserver image generates a random password on first run. Find it in the logs before logging in:

```bash
docker compose logs qbittorrent | grep -i password
```

Look for a line like: `A temporary password is provided for this session: XXXXXXXX`

Username is `admin`. After logging in, go to Tools → Options → Web UI → change the password to something permanent and save. Also update `QBITTORRENT_PASSWORD` in `.env`.

## Downloads

1. Tools → Options → Downloads
   - Default save path: `/data/torrents`
   - Keep incomplete torrents in: `/data/torrents`

## Categories

Used by *arr apps to sort downloads into the right folders:

1. Right-click the category list on the left → Add category:
   - `tv-sonarr` → save path `/data/torrents/tv`
   - `radarr` → save path `/data/torrents/movies`
   - `lidarr-music` → save path `/data/torrents/music`

## Seeding limits

1. Tools → Options → BitTorrent → Seeding Limits
   - Check "When ratio reaches" → set to `1` (ratio 1.0 means you've uploaded as much as you downloaded — fair contribution to the swarm)
   - Check "When total seeding time reaches" → set to `60` minutes (safety net in case the ratio is never reached)
   - then: `Stop torrent` — important: Sonarr/Radarr can't move or rename the file while it's being seeded; stopping it triggers their post-processing

## Troubleshooting

### Container stuck unhealthy, port 8080 never binds

Symptom: `qbittorrent.log` shows qBittorrent starting and immediately terminating in a tight loop (`qBittorrent v5.2.0 started` → `termination initiated` → `is now ready to exit`, every ~1s). The healthcheck never passes because nothing ever listens on 8080.

Cause: stale `lockfile` and `ipc-socket` in `/config/qBittorrent/` left over from an unclean shutdown. Each new instance sees them, assumes another qBittorrent is already running, hands its args off via IPC, and exits. s6 respawns it forever.

Fix:

```bash
docker stop qbittorrent
rm config/qbittorrent/qBittorrent/lockfile config/qbittorrent/qBittorrent/ipc-socket
docker start qbittorrent
```
