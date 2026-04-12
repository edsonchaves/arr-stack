# NAS Server

A self-hosted home media server stack running on Docker Compose. Covers the full pipeline from content discovery and automated downloading to streaming, with Mullvad VPN protection, Nvidia GPU transcoding, and secure remote access.

---

## Architecture Overview

```
You → Jellyseerr (request) → Sonarr/Radarr/Lidarr/Readarr (manage)
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

### Media Management

| Container | Port | Purpose |
|---|---|---|
| prowlarr | 9696 | Manages all torrent indexers in one place. Syncs to all *arr apps |
| flaresolverr | — | Bypasses Cloudflare protection on indexers. Internal only |
| sonarr | 8989 | Monitors and downloads TV series |
| radarr | 7878 | Monitors and downloads movies |
| lidarr | 8686 | Monitors and downloads music |
| readarr | 8787 | Monitors and downloads books and audiobooks |
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
| huntarr | 9705 | Searches for missing episodes/movies and quality upgrades |
| cleanuparr | 11011 | Removes stuck and stalled downloads from *arr queues |
| jellystat | 8288 | Jellyfin watch history and statistics |
| jellystat-db | — | PostgreSQL database backing Jellystat |
| maintainerr | 6246 | Rule-based media cleanup (e.g. delete watched movies after 30 days) |
| notifiarr | 5454 | Sends notifications to Discord/Telegram for *arr events |

### Dashboard

| Container | Port | Purpose |
|---|---|---|
| homepage | 3000 | Unified dashboard with live widgets for all services |

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
    ├── readarr/
    ├── bazarr/
    ├── jellyfin/
    ├── jellyseerr/
    ├── prowlarr/
    ├── qbittorrent/
    ├── calibre-web/
    ├── komga/
    ├── tdarr/
    ├── recyclarr/
    │   └── recyclarr.yml     ← quality profile sync config
    ├── jellystat/
    ├── jellystat-db/
    ├── maintainerr/
    ├── notifiarr/
    ├── uptime-kuma/
    ├── wg-easy/
    ├── homepage/
    ├── huntarr/
    ├── cleanuparr/
    └── autobrr/

/mnt/data/                    ← media storage (plan: TrueNAS Scale)
├── media/
│   ├── movies/
│   ├── tv/
│   ├── music/
│   ├── books/
│   └── comics/
└── torrents/
    ├── movies/
    ├── tv/
    ├── music/
    └── other/
```

> All service configurations are bind-mounted from `config/`. Settings you configure via the web UI (quality profiles, indexers, download clients, etc.) are persisted there automatically and survive container restarts and image upgrades.

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
sudo mkdir -p /mnt/data/{media/{movies,tv,music,books,comics},torrents/{movies,tv,music,other}}
sudo chown -R $USER:$USER /mnt/data
```

### Step 2 — Create config directories

```bash
mkdir -p ~/nas-server/config/{sonarr,radarr,lidarr,readarr,bazarr,jellyfin,jellyseerr,prowlarr,qbittorrent,calibre-web,komga,homepage,huntarr,cleanuparr,tdarr/{server,configs,logs},recyclarr,jellystat,jellystat-db,maintainerr,notifiarr,uptime-kuma,wg-easy,autobrr}
```

### Step 3 — Fill in `.env`

Open [`.env`](.env) and fill in:

| Variable | Where to get it |
|---|---|
| `USER_ID` / `GROUP_ID` | Run: `id -u` and `id -g` |
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

## Post-Install UI Configuration

Configure services in this order. Each service stores all settings in its `config/` directory — you only do this once.

### 1. Prowlarr — `http://localhost:9696`
- Settings → Indexers → Add FlareSolverr proxy: URL = `http://flaresolverr:8191`
- Indexers → Add your torrent indexers (1337x, YTS, etc.)
- Settings → Apps → Add Sonarr, Radarr, Lidarr, Readarr (they will auto-sync indexers)

### 2. qBittorrent — `http://localhost:8080`
- Change the default password on first login
- Create download categories: `tv-sonarr`, `radarr`, `lidarr-music`, `readarr-books`

### 3. Sonarr/Radarr/Lidarr/Readarr
For each app:
- Settings → Media Management → Add root folder:
  - Sonarr: `/data/media/tv`
  - Radarr: `/data/media/movies`
  - Lidarr: `/data/media/music`
  - Readarr: `/data/media/books`
- Settings → Download Clients → Add qBittorrent: host = `vpn`, port = `8080`
- Indexers are synced automatically from Prowlarr

### 4. Fill in API keys
In each app: Settings → General → copy the API Key.
Paste into `.env`, then restart containers that use them:

```bash
docker compose up -d
```

### 5. Bazarr — `http://localhost:6767`
- Settings → Sonarr → URL: `http://sonarr:8989`, API key from `.env`
- Settings → Radarr → URL: `http://radarr:7878`, API key from `.env`
- Settings → Languages → Add Brazilian Portuguese
- Settings → Providers → Add OpenSubtitles or another provider

### 6. Jellyfin — `http://localhost:8096`
- Create admin account on first launch
- Add libraries: `/data/media/movies`, `/data/media/tv`, `/data/media/music`
- Admin Dashboard → Playback → Enable NVENC hardware transcoding

### 7. Jellyseerr — `http://localhost:5055`
- Sign in with Jellyfin account
- Connect to Sonarr + Radarr using `http://sonarr:8989` etc.
- Set request permissions for your users

### 8. Tdarr — `http://localhost:8265`
- Add library pointing to `/media`
- Configure an H.265 Nvidia NVENC plugin
- Set worker count to 1 or 2

### 9. Recyclarr — config file only
Edit [`config/recyclarr/recyclarr.yml`](config/recyclarr/recyclarr.yml):
- Create `config/recyclarr/secrets.yml` with your Sonarr and Radarr API keys
- Uncomment the quality profiles you want
- Test manually: `docker compose exec recyclarr recyclarr sync`

### 10. Remaining services
- **Jellystat** — connect to Jellyfin at `http://localhost:8096`
- **Maintainerr** — connect to Jellyfin + Sonarr/Radarr, define cleanup rules
- **Notifiarr** — add API key, configure Discord/Telegram webhook
- **Uptime Kuma** — add an HTTP monitor for each service URL
- **WG-Easy** — `http://localhost:51821` — create WireGuard client configs for your devices

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

### Reverse Proxy + Domain
When a domain is acquired, Nginx Proxy Manager or Traefik can be added to give each service a clean HTTPS URL and enable access from outside the home network without WireGuard (useful for sharing Jellyfin with others).

### TrueNAS Scale
The stack is designed to migrate to TrueNAS Scale by remapping `DATA_ROOT` in `.env` to the NAS mount point. All service configs remain unchanged.
