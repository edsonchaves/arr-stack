# NAS Server

A self-hosted home media server stack running on Docker Compose. Covers the full pipeline from content discovery and automated downloading to streaming, with Mullvad VPN protection, Nvidia GPU transcoding, and secure remote access.

---

## Architecture Overview

```
You → Jellyseerr (request) → Sonarr/Radarr/Lidarr (manage)
                                        ↓
                              Prowlarr (find on indexers)
                                        ↓
                              qBittorrent (download via Mullvad VPN)
                                        ↓
                              Unpackerr (extract if needed)
                                        ↓
                              /mnt/data/media (final library)
                                        ↓
                              Jellyfin (stream anywhere)
```

All services run on the internal `nas` Docker network and communicate via container name. No reverse proxy — services are accessed directly via `localhost:PORT` on your local network.

---

## Services

### Infrastructure

| Container | Port | Purpose |
|---|---|---|
| autoheal | — | Automatically restarts any unhealthy container |
| watchtower | — | Automatically updates all container images |
| uptime-kuma | 3001 | Service health dashboard with uptime graphs |
| wg-easy | 51820/udp, 51821 | WireGuard VPN server — remote access to your home network |

### VPN + Download

| Container | Port | Purpose |
|---|---|---|
| vpn (Gluetun) | — | Mullvad WireGuard VPN. qBittorrent routes all traffic through it |
| qbittorrent | 8080 | Torrent client with VueTorrent UI. Will not download without a healthy VPN |
| rdt-client | 6500 | Real-Debrid downloader. qBit-compatible API; downloads files via RD's CDN over HTTPS — no torrent peering on local IP, no VPN needed |
| pinchflat | 8945 | YouTube channel/playlist subscriptions via yt-dlp. Names files as `Show/Season XX/SXXEYY` so Jellyfin matches them against TVDB |

### Media Management

| Container | Port | Purpose |
|---|---|---|
| prowlarr | 9696 | Manages all torrent indexers in one place. Syncs to all *arr apps |
| flaresolverr | — | Bypasses Cloudflare protection on indexers. Internal only |
| sonarr | 8989 | Monitors and downloads TV series |
| radarr | 7878 | Monitors and downloads movies |
| lidarr | 8686 | Monitors and downloads music |
| bazarr | 6767 | Automatically downloads subtitles (Brazilian Portuguese) |
| jellyseerr | 5055 | Netflix-style UI to browse and request content |
| recyclarr | — | Syncs TRaSH Guide quality profiles to Sonarr/Radarr daily |

### Media Servers

| Container | Port | Purpose |
|---|---|---|
| jellyfin | 8096 | Media streaming server with Nvidia hardware transcoding |
| calibre-web | 8083 | Ebook library and reader |
| komga | 25600 | Comics and manga server and reader |

### Transcoding

| Container | Port | Purpose |
|---|---|---|
| tdarr-server | 8265 | Manages H.265 transcoding queue and web UI |
| tdarr-node | — | Performs transcoding using the Nvidia GPU |

### Automation & Monitoring

| Container | Port | Purpose |
|---|---|---|
| unpackerr | — | Auto-extracts `.rar`/`.zip` archives after download |
| cleanuparr | 11011 | Removes stuck and stalled downloads from *arr queues |
| jellystat | 8288 | Jellyfin watch history and statistics |
| jellystat-db | — | PostgreSQL database backing Jellystat |
| maintainerr | 6246 | Rule-based media cleanup (e.g. delete watched movies after 30 days) |

### Dashboard

| Container | Port | Purpose |
|---|---|---|
| homepage | 3090 | Unified dashboard with live widgets for all services |

### Optional (Docker Profile)

| Container | Port | Purpose | How to enable |
|---|---|---|---|
| autobrr | 7474 | Grabs new releases from private trackers via IRC/RSS | `docker compose --profile private-trackers up -d autobrr` |

---

## Directory Layout

```
/home/edson/nas-server/       ← this repo
├── docker-compose.yml
├── .env                      ← all secrets and config (never commit this)
└── config/                   ← persistent service configs (all UI settings live here)
    ├── sonarr/
    ├── radarr/
    ├── lidarr/
    ├── bazarr/
    ├── jellyfin/
    ├── jellyseerr/
    ├── prowlarr/
    ├── qbittorrent/
    ├── calibre-web/
    ├── komga/
    ├── pinchflat/
    ├── tdarr/
    ├── recyclarr/
    │   └── recyclarr.yml     ← quality profile sync config
    ├── jellystat/
    ├── jellystat-db/
    ├── maintainerr/
    ├── uptime-kuma/
    ├── wg-easy/
    ├── homepage/
    ├── cleanuparr/
    └── autobrr/

/mnt/data/                    ← media storage (plan: TrueNAS Scale)
├── media/
│   ├── movies/
│   ├── tv/
│   ├── music/
│   ├── books/
│   ├── comics/
│   └── youtube-shows/   ← Pinchflat-managed series (Show/Season XX/SXXEYY)
└── torrents/
    ├── movies/
    ├── tv/
    ├── music/
    └── other/
```

> All service configurations are bind-mounted from `config/`. Settings you configure via the web UI (quality profiles, indexers, download clients, etc.) are persisted there automatically and survive container restarts and image upgrades.

---

## WSL2 Networking (Windows only)

When running on WSL2, services are not directly reachable from other devices on your LAN (TV, phone, etc.) because WSL2 runs in an isolated VM. You need to set up a **port proxy** on Windows to forward traffic into WSL2.

### Expose Jellyfin to your LAN

Run in **PowerShell as Administrator** (replace `<WSL2_IP>` with the output of `wsl hostname -I`):

```powershell
# Get your WSL2 IP
wsl hostname -I

# Forward Jellyfin port from Windows to WSL2
netsh interface portproxy add v4tov4 listenport=8096 listenaddress=0.0.0.0 connectport=8096 connectaddress=<WSL2_IP>

# Allow through Windows Firewall
netsh advfirewall firewall add rule name="Jellyfin" dir=in action=allow protocol=TCP localport=8096
```

Then connect using your **Windows LAN IP** (from `ipconfig` — look for Wi-Fi or Ethernet IPv4 address):
```
http://192.168.x.x:8096
```

### Notes

- **WSL2 IP changes on reboot** — you'll need to redo the portproxy after each restart, or automate it with a startup script
- **NordVPN / other VPNs on Windows** can interfere — disable them temporarily if the connection fails
- To repeat for other services (e.g. Homepage on 3090, qBittorrent on 8080), add a portproxy rule for each port
- Verify existing portproxy rules: `netsh interface portproxy show all`
- Remove a rule: `netsh interface portproxy delete v4tov4 listenport=8096 listenaddress=0.0.0.0`

### Nvidia GPU transcoding on WSL2 (libnvcuvid fix)

On WSL2, the NVIDIA video codec libraries (`libnvcuvid.so.1`) are not automatically passed into Docker containers even when the GPU is otherwise visible (`nvidia-smi` works). This causes Jellyfin's FFmpeg to fail with:

```
Cannot load libnvcuvid.so.1
Failed loading nvcuvid.
Failed setup for format cuda: hwaccel initialisation returned error.
```

**Fix — already applied in `docker-compose.yml`:**

The Jellyfin service mounts the WSL2 NVIDIA library path and exposes it to FFmpeg:

```yaml
environment:
  - LD_LIBRARY_PATH=/usr/lib/wsl/lib
volumes:
  - /usr/lib/wsl/lib:/usr/lib/wsl/lib:ro
```

This makes `libnvcuvid.so.1` accessible inside the container and enables NVENC/NVDEC hardware transcoding. Without this, Jellyfin falls back to software transcoding (or fails entirely).

To verify it's working after a fresh deploy:
```bash
docker compose exec jellyfin find /usr/lib/wsl/lib -name "libnvcuvid*"
# Should return: /usr/lib/wsl/lib/libnvcuvid.so.1
```

### Jellyfin library monitoring on WSL2

Jellyfin uses inotify to watch for new files. On WSL2, inotify events from Docker bind-mounted volumes can occasionally be missed, meaning new downloads won't appear in Jellyfin automatically.

**Workaround — increase scan frequency:**

**Jellyfin → Dashboard → Scheduled Tasks → Scan Media Library** → set interval to **15–30 minutes**.

This ensures new content appears within 30 minutes even if real-time monitoring misses an event. Real-time monitoring should still be enabled (`Dashboard → Libraries → Edit → Enable real time monitoring`) as it works most of the time.

---

## Prerequisites

### 1. Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### 2. Nvidia Container Toolkit (for Jellyfin and Tdarr GPU transcoding)

```bash
# Add Nvidia package repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

# Configure Docker runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## First-Time Setup

### Step 1 — Create storage directories

```bash
sudo mkdir -p /mnt/data/{media/{movies,tv,music,books,comics,youtube-shows},torrents/{movies,tv,music,other}}
sudo chown -R $USER:$USER /mnt/data
```

### Step 2 — Create config directories

```bash
mkdir -p ~/nas-server/config/{sonarr,radarr,lidarr,bazarr,jellyfin,jellyseerr,prowlarr,qbittorrent,calibre-web,komga,pinchflat,homepage,cleanuparr,tdarr/{server,configs,logs},recyclarr,jellystat,jellystat-db,maintainerr,uptime-kuma,wg-easy,autobrr}
```

### Step 3 — Create and fill in `.env`

Copy the template and fill in your values:

```bash
cp .env.template .env
```

Open [`.env.template`](.env.template) as a reference. Variables to fill in:

| Variable | Where to get it |
|---|---|
| `USER_ID` / `GROUP_ID` | Run: `id -u` and `id -g` |
| `CONFIG_ROOT` | Absolute path to this repo's `config/` directory |
| `MULLVAD_PRIVATE_KEY` | mullvad.net → Account → WireGuard keys → Generate key |
| `MULLVAD_ADDRESSES` | Same page, the IP address assigned to the key |
| `MULLVAD_CITY` | e.g. `Frankfurt`, `Amsterdam`, `Stockholm` |
| `SERVER_LAN_IP` | Run: `hostname -I \| awk '{print $1}'` |
| `WGEASY_PASSWORD_HASH` | Run: `docker run ghcr.io/wg-easy/wg-easy wgpw YOUR_PASSWORD` |
| `JELLYSTAT_DB_PASSWORD` | Choose any strong password |
| `JELLYSTAT_JWT_SECRET` | Choose any long random string |

Leave all `*_API_KEY` fields empty for now — you will fill them after first run.

### Step 4 — Start the stack

```bash
cd ~/nas-server
docker compose up -d
```

Check all containers are running:

```bash
docker compose ps
```

Verify qBittorrent is behind the VPN (must show a Mullvad IP, not your real one):

```bash
docker compose exec qbittorrent curl ifconfig.me
```

---

## Background Service Configuration

These services have no web UI. Configure them via files before or after starting the stack.

### [Recyclarr](docs/recyclarr.md) — config file only
Create `config/recyclarr/secrets.yml` with your Sonarr and Radarr API keys. Syncs TRaSH Guide quality profiles automatically on a schedule.

### [Unpackerr](docs/unpackerr.md) — configured via `.env`
No extra steps needed — it reads `SONARR_API_KEY`, `RADARR_API_KEY`, and `LIDARR_API_KEY` directly from `.env`. Will auto-extract archives once the keys are filled in.

### [Autoheal](docs/autoheal.md) — zero config
Monitors all containers with a healthcheck and restarts unhealthy ones automatically. Nothing to configure.

### [Watchtower](docs/watchtower.md) — zero config
Checks for updated container images every 24 hours and applies them automatically. Nothing to configure.

---

## Post-Install UI Configuration

Configure services in this order. Each service stores all settings in its `config/` directory — you only do this once. Click any step for the full setup instructions.

### 1. [Prowlarr](docs/prowlarr.md) — `http://localhost:9696`
Add the FlareSolverr proxy and your indexers.

### 2. [qBittorrent](docs/qbittorrent.md) — `http://localhost:8080`
Set credentials, download paths, categories, and seeding limits.

### 2b. [rdt-client](docs/rdt-client.md) — `http://localhost:6500` *(optional, recommended)*
Real-Debrid downloader — qBit-compatible API, no torrent peering on your local IP. Add the RD API token, set the download path, then point Sonarr/Radarr at it as a download client. With rdt-client at priority 1 and qBittorrent at priority 25, new grabs default to RD with qBit as a fallback.

### 3. [Sonarr / Radarr / Lidarr](docs/arr-apps.md)
Configure authentication, root folders, and qBittorrent as the download client.

### 4. [Connect Prowlarr to *arr apps](docs/prowlarr.md#4-connect-prowlarr-to-arr-apps)
Full Sync so all indexers push to Sonarr, Radarr, and Lidarr automatically.

### 5. [Bazarr](docs/bazarr.md) — `http://localhost:6767`
Set up Brazilian Portuguese subtitles and connect to Sonarr and Radarr.

### 6. [Jellyfin](docs/jellyfin.md) — `http://localhost:8096`
Run the setup wizard, add media libraries, and enable Nvidia hardware transcoding.

### 7. [Jellyseerr](docs/jellyseerr.md) — `http://localhost:5055`
Connect to Jellyfin, sync libraries, and link Sonarr and Radarr.

Once all keys are in `.env`, apply them:

```bash
docker compose up -d
```

> This restarts Homepage and Unpackerr with the new keys — Homepage will show live stats widgets, and Unpackerr will auto-extract completed downloads.

### 8. [Tdarr](docs/tdarr.md) — `http://localhost:8265`
Add the media library, build the Nvidia H.265 plugin stack, and configure transcode workers.

### 9. [Calibre-Web](docs/calibre-web.md) — `http://localhost:8083`
Set the database path and enable the in-browser ebook viewer.

### 10. [Komga](docs/komga.md) — `http://localhost:25600`
Create an admin account and add the comics library at `/data/comics`.

### 11. [Jellystat](docs/jellystat.md) — `http://localhost:8288`
Connect to Jellyfin with a dedicated API key to start pulling watch history.

### 12. [Maintainerr](docs/maintainerr.md) — `http://localhost:6246`
Connect to Jellyfin, Sonarr, and Radarr, then create rules to auto-delete watched media.

### 13. [Uptime Kuma](docs/uptime-kuma.md) — `http://localhost:3001`
Add one HTTP monitor per service and configure a notification channel.

### 14. [WG-Easy](docs/wg-easy.md) — `http://localhost:51821`
Create WireGuard clients for each device that needs remote access to your home network.

### 15. [Cleanuparr](docs/cleanuparr.md) — `http://localhost:11011`
Connect to *arr apps, then choose your scenario: Queue Cleaner (stalled downloads), Malware Blocker, or qBittorrent file exclusion.

### 16. [Homepage](docs/homepage.md) — `http://localhost:3090`
Tiles and widgets auto-populate from Docker labels once all API keys are in `.env`.

### 17. [Pinchflat](docs/pinchflat.md) — `http://localhost:8945`
Subscribe to YouTube channels or playlists that should appear in Jellyfin as a TV show (e.g. PT-BR-dubbed Bluey / Pokémon playlists). Files land in `/mnt/data/media/youtube-shows/` with `Show/Season XX/SXXEYY` naming so TVDB metadata matches automatically.

### 18. [Autobrr](docs/autobrr.md) — `http://localhost:7474` _(optional — private trackers)_
Connect to qBittorrent, add IRC networks and filters for each private tracker.

---

## Common Operations

```bash
# Start everything
docker compose up -d

# Stop everything
docker compose down

# Restart a single service
docker compose restart sonarr

# View logs
docker compose logs -f sonarr
docker compose logs -f vpn

# Update all images
docker compose pull && docker compose up -d

# Enable private tracker support (Autobrr)
docker compose --profile private-trackers up -d autobrr

# Check VPN is working
docker compose exec qbittorrent curl ifconfig.me
```

---

## Backup

All settings configured via the web UI are persisted in `config/`. Back up that directory plus `.env`:

```bash
tar -czf ~/backups/nas-config-$(date +%Y%m%d).tar.gz \
  ~/nas-server/config \
  ~/nas-server/.env
```

To restore on a new machine:
1. Install Docker and nvidia-container-toolkit
2. Extract backup to the same paths
3. Create storage directories (Step 1 above)
4. `docker compose up -d`

All service settings come back automatically — no UI reconfiguration needed.

---

## Future Plans

### Real-Debrid
A Zurg + rclone integration is planned for when a Real-Debrid subscription is added. This will mount the Real-Debrid library as a local folder at `/mnt/data/realdebrid`, making cached torrents available instantly without needing to download them. The VPN becomes optional for those downloads.

### Vulnerability Scanning
The Huntarr incident (exposed API keys, no auth, insecure code) is a reminder that community Docker images can be dangerous. Watchtower keeps images updated but doesn't check for known CVEs or bad practices.

Planned addition: **Trivy** — the most widely used open-source container vulnerability scanner.

```bash
# Scan a single image on demand
docker run --rm aquasec/trivy image lscr.io/linuxserver/sonarr:latest

# Scan all images in the stack at once
docker compose config | grep 'image:' | awk '{print $2}' | sort -u | \
  xargs -I {} docker run --rm aquasec/trivy image {}
```

Longer term: add Trivy as a scheduled service in the compose that scans all images weekly and sends results via a notification channel.

Beyond scanning, habits that reduce risk:
- Prefer images from linuxserver.io, official Docker Hub, or well-known GitHub orgs — avoid random Docker Hub accounts
- Check a project's GitHub before adding it — look at contributor count, recent activity, open issues
- Review what ports a new container exposes before starting it

### Reverse Proxy + Domain
When a domain is acquired, Nginx Proxy Manager or Traefik can be added to give each service a clean HTTPS URL and enable access from outside the home network without WireGuard (useful for sharing Jellyfin with others).

### TrueNAS Scale
The stack is designed to migrate to TrueNAS Scale by remapping `DATA_ROOT` in `.env` to the NAS mount point. All service configs remain unchanged.

### Missing Content Search (Huntarr replacement)
Huntarr was removed in February 2026 after the community discovered it exposed all *arr API keys and passwords to anyone on the local network or internet with no authentication required. The project and its GitHub/subreddit were deleted. **Do not use it.**

The image pull failing with "denied" meant it never ran here — no API keys were exposed.

Community replacements built with security in mind:

| Option | Notes |
|---|---|
| **Fetcharr** | Built as a secure replacement, focused on safe API handling |
| **Newtarr** | Sane fork of the same concept |
| **Seekarr** | Search automation for Sonarr/Radarr |

**In the meantime:** Sonarr/Radarr/Lidarr have built-in scheduled searches under Settings → General → Task Schedule. Enable "Search for missing" and "Search for cutoff unmet" — covers the same use case without a third-party tool.

### Photo Management (Immich)
Self-hosted Google Photos replacement. Backs up photos and videos from your phone, with face recognition, album sharing, and a mobile app. Would live alongside Jellyfin — Jellyfin for media you download, Immich for personal photos.

Immich requires four containers: `immich-server`, `immich-machine-learning` (AI features), a dedicated PostgreSQL instance with the pgvector extension, and Redis. Storage goes under `/mnt/data/photos`.

- Image: `ghcr.io/immich-app/immich-server:release`
- Port: `2283`
- Docs: https://immich.app/docs/install/docker-compose

### Metrics Dashboards (Prometheus + Grafana)
Uptime Kuma covers availability (is the service up?), but Prometheus + Grafana adds time-series metrics: CPU, RAM, disk I/O, and per-container resource usage with historical graphs and alerting.

The stack needs three additional containers:
- **Prometheus** (`prom/prometheus`) — scrapes and stores metrics. Port `9090`.
- **Grafana** (`grafana/grafana`) — visualization and dashboards. Port `3030`.
- **node-exporter** (`prom/node-exporter`) — exports host system metrics (CPU, RAM, disk, network). Internal only.
- **cAdvisor** (`gcr.io/cadvisor/cadvisor`) — exports per-container resource metrics. Internal only. Requires `privileged: true`.

After adding, configure in Grafana:
1. Add Prometheus data source: `http://prometheus:9090`
2. Import community dashboards by ID from grafana.com:
   - **1860** — Node Exporter Full (host system metrics)
   - **14282** — Docker container metrics via cAdvisor

### Book Automation (Readarr replacement)
Readarr (the *arr-style book manager) was retired in 2025. Candidates to replace it:

| Option | Status | Notes |
|---|---|---|
| **LazyLibrarian** | Active | Monitors RSS feeds per author, integrates with qBittorrent + Prowlarr, sorts and renames. Docker image: `linuxserver/lazylibrarian` |
| **BookBounty** | Early dev | Built as a direct Readarr successor. Watch: https://github.com/TheWicklowWolf/BookBounty |

When adding, wire it up the same way as the other *arr apps: Prowlarr for indexers, qBittorrent (`host: vpn`, `port: 8080`) as download client, `/data/media/books` as root folder.
