# Cleanuparr Setup

**URL:** `http://localhost:11011`

Cleanuparr monitors your *arr queues and automatically removes stuck, stalled, or malicious downloads. Configure it after your *arr apps are running and their API keys are in `.env`.

## Connect your *arr apps

1. Open `http://localhost:11011`
2. Settings → for each app, add the connection:

   | App | URL | API Key |
   |---|---|---|
   | Sonarr | `http://sonarr:8989` | from Sonarr → Settings → General → Security |
   | Radarr | `http://radarr:7878` | from Radarr → Settings → General → Security |
   | Lidarr | `http://lidarr:8686` | from Lidarr → Settings → General → Security |

Then enable one or more scenarios below depending on what you need.

---

## Scenario A — Stalled download cleanup (Queue Cleaner)

The baseline setup. Queue Cleaner watches for downloads that are stuck or stalled and removes them from the *arr queue after a configurable number of strikes.

1. Settings → Queue Cleaner → **Enable**
2. Set **Max Strikes** — how many consecutive failed checks before a download is removed (e.g. `5`)
3. Optionally enable **Failed Import Max Strikes** — removes downloads that completed but could not be imported (e.g. wrong format, corrupt file) after the same strike threshold

---

## Scenario B — Malware Blocker (Cleanuparr's built-in)

Blocks torrents that contain known malicious filenames using a community-maintained blocklist. When a match is found the torrent is removed from the queue before any files are kept.

1. Settings → Malware Blocker → **Enable**
2. Select a blocklist source:
   - **Standard blacklist** (recommended) — the official blocklist maintained in the Cleanuparr repository
   - **Permissive blacklist** — less restrictive, fewer false positives
   - **Custom** — paste your own list of blocked filename patterns

---

## Scenario C — qBittorrent file exclusion (alternative to Scenario B)

Uses qBittorrent's native excluded filenames feature instead of Cleanuparr's blocker. When a restricted file is detected, qBittorrent marks the torrent as complete without downloading anything — Cleanuparr's Queue Cleaner then picks it up and removes it from the *arr queue.

1. qBittorrent → Tools → Options → Downloads → check **Excluded file names**
2. Paste the blocklist content (same sources as Scenario B above)
3. Make sure Cleanuparr's Queue Cleaner (Scenario A) is enabled — it handles the resulting "completed" torrents in the *arr queues

---

> **Recommended starting point:** Enable Scenario A (Queue Cleaner) as the baseline — it handles the most common issue of stuck downloads. Add Scenario B or C if you want malicious file protection. Scenarios B and C cover the same threat in different ways — pick one, not both.
