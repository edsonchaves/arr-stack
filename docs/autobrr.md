# Autobrr Setup

**URL:** `http://localhost:7474`

> **Optional service** — only needed for private trackers. Enable with:
> ```bash
> docker compose --profile private-trackers up -d autobrr
> ```

Autobrr watches IRC announce channels on private trackers and grabs new releases the moment they're announced — before they hit RSS feeds.

## First-time setup

1. On first launch, create an admin account
2. Go to **Settings → API Keys** → `+ Add` → copy the key → paste as `AUTOBRR_API_KEY` in `.env`
3. Restart the stack: `docker compose up -d` so Homepage picks up the widget key

## Download client

Connect Autobrr to qBittorrent so it can push grabbed torrents:

1. Settings → Download Clients → `+ Add`
2. Select `qBittorrent`
3. Fill in:
   - Name: `qBittorrent`
   - Host: `vpn` (qBittorrent shares the VPN container's network)
   - Port: `8080`
   - Username and Password: your qBittorrent credentials
4. Test → Save

## IRC networks

Each private tracker has its own IRC announce network. Add one per tracker:

1. Settings → IRC Networks → `+ Add network`
2. Fill in the server, port, SSL, nickname, and NickServ password from your tracker's IRC announce documentation
3. Add the announce channel(s) for that tracker

## Filters

Filters define what to grab from the announce stream:

1. Filters → `+ New filter`
2. Fill in:
   - Name: descriptive name (e.g. `Sonarr — HD TV`)
   - Indexers: select the IRC network/tracker this filter applies to
   - Use `Shows`, `Seasons`, `Episodes`, or `Movies` match fields to limit scope
3. Under **Actions** → `+ Add action`:
   - Type: `qBittorrent`
   - Client: your qBittorrent client
   - Category: `tv-sonarr` / `radarr` / `lidarr-music` — must match the category *arr apps monitor
4. Save

## Connect to *arr apps (optional)

For smarter filtering — only grab releases for shows/movies you're actually monitoring — connect Autobrr to your *arr apps:

1. Settings → Indexers → select your tracker → enable **Sonarr** / **Radarr** integration
2. Fill in URL (`http://sonarr:8989`) and API key
3. Enable **"Must be in Sonarr's queue"** in the filter → Autobrr will only grab releases for monitored items

> **Save to `.env`:** Settings → API Keys → copy key → paste as `AUTOBRR_API_KEY` in `.env`
