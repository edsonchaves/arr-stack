# Prowlarr Setup

**URL:** `http://localhost:9696`

## 1a. Add FlareSolverr proxy

FlareSolverr bypasses Cloudflare protection on indexers that require it (e.g. 1337x). It works via tags — any indexer tagged `flaresolverr` will automatically route through it.

1. Settings → Indexers → + Add Proxy
2. Select type: `FlareSolverr`
3. Fill in:
   - Name: `FlareSolverr`
   - Tags: `flaresolverr` (type it and press Enter to create the tag)
   - Host: `http://flaresolverr:8191`
4. Test → Save

## 1b. Add indexers

1. Indexers → + Add Indexer
2. Search for the indexer by name (e.g. `1337x`, `YTS`, `EZTV`)
3. For indexers that require Cloudflare bypass (like 1337x):
   - In the indexer config, find the **Tags** field
   - Add the `flaresolverr` tag — this tells Prowlarr to route requests through FlareSolverr
4. Test → Save
5. Repeat for each indexer you want to add

> You will connect Prowlarr to Sonarr/Radarr/Lidarr after those apps are configured.

> **Save to `.env`:** Settings → General → Security → copy the API Key → paste as `PROWLARR_API_KEY` in `.env`

## 4. Connect Prowlarr to *arr apps

Now that Sonarr, Radarr, and Lidarr are running, go back to Prowlarr and link them. This pushes all your indexers to each app automatically.

1. Prowlarr → Settings → Apps → + Add Application
2. Add each app separately using the values below.
   The pre-filled URLs use `localhost` — replace them with container names so the containers can reach each other:

   | Field | Sonarr | Radarr | Lidarr |
   |---|---|---|---|
   | Sync Level | `Full Sync` | `Full Sync` | `Full Sync` |
   | Tags | leave empty | leave empty | leave empty |
   | Prowlarr Server | `http://prowlarr:9696` | `http://prowlarr:9696` | `http://prowlarr:9696` |
   | App Server | `http://sonarr:8989` | `http://radarr:7878` | `http://lidarr:8686` |
   | API Key | Sonarr → Settings → General → Security → API Key | same for Radarr | same for Lidarr |

3. Test → Save after each one

After this, every indexer in Prowlarr is available in all three apps — no manual indexer config needed inside each app.

## 5. Torrentio custom indexers — do NOT set a debrid key

The Torrentio indexers use custom Cardigann definitions in `config/prowlarr/Definitions/Custom/` (`torrentio.yml`, `torrentio-br-dublado-series.yml`).

**Never fill in the "Debrid provider API Key" field on these indexers.** With a Real-Debrid key set, Torrentio returns `[RD download]` resolve-URL streams that have no `infoHash` field, which crashes the parser on every search:

```
CardigannException: Error while parsing field=infohash, selector=infoHash:
Selector "infoHash" didn't match JSON content
```

The indexer then silently fails every query, Sonarr/Radarr put it in failure backoff, and new episodes stop being grabbed (this killed all ATVP-show grabs for ~3 weeks in Jul 2026). RD-mode streams are only usable inside Stremio anyway — Prowlarr → qBittorrent needs the plain infohash mode.

The `|realdebrid=<key>` segment has been removed from the URL templates in `torrentio.yml`. Note when editing these definitions: Prowlarr's Cardigann template engine does **not** support nested `{{ if }}` blocks in `path:` — the inner block renders literally into the URL. Definitions are only reloaded on container restart (`docker restart prowlarr`).
