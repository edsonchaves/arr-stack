# rdt-client Setup

**URL:** `http://localhost:6500`

rdt-client is a Real-Debrid downloader with a qBittorrent-compatible API. Sonarr / Radarr add torrents here, rdt-client forwards the magnet to RD's servers (no torrent traffic ever touches this network or VPN), then downloads completed files from RD's CDN to local disk over HTTPS.

End result: real local files, like qBittorrent — without any torrent peering from your IP.

> **No VPN.** rdt-client runs on the normal `nas` network. RD does the actual torrent peering on their infrastructure, so your IP never appears in any swarm. Only HTTPS to `real-debrid.com` leaves the box.

## First run — create the admin user

1. Open `http://localhost:6500/`
2. Enter a username (`admin` is fine) and a strong password → Create.
3. Log in with those credentials.

> If you mistyped and need to reset: stop the container, delete the contents of `config/rdt-client/`, then restart and create again.

## 1. Provider — Real-Debrid

1. Get your token at https://real-debrid.com/apitoken
2. Settings (top right gear) → **Provider** section:
   - Provider: `RealDebrid`
   - API Key: paste your token
3. Save Settings (top of page).

## 2. Download paths

In Settings → **Download Client** section:

- Download path: `/data/torrents/rdt-client` — this is the path *inside* the container.
- Mapped path: `/data/torrents/rdt-client` — same path on host (used so the *arrs see the same path and no remote-path-mapping is needed).

The compose file mounts `${DATA_ROOT}/torrents/rdt-client` to that exact in-container path, and the *arrs see it via their existing `/data` mount at the same path.

Save Settings.

## 3. Categories

In Settings → **General** section:

- Categories: `tv-sonarr,radarr`

This exposes those categories through the qBittorrent-compatible API so Sonarr and Radarr can route downloads correctly. Subfolders (`/data/torrents/rdt-client/tv-sonarr/`, `/data/torrents/rdt-client/radarr/`) are created automatically on first use, but you can pre-create them to silence Sonarr's "directory does not exist" warning:

```bash
mkdir -p /mnt/data/torrents/rdt-client/{tv-sonarr,radarr}
sudo chown -R $USER:$USER /mnt/data/torrents/rdt-client
```

Save Settings.

## 4. ⚠️ Do NOT enable AutoImport

Settings → **Provider** has an option called `AutoImport`. **Leave it off.**

When enabled, rdt-client scans your existing RD account and queues *every torrent in it* for local download. If you've been using RD for a while, this can be hundreds of items — gigabytes pulled to disk in minutes without you asking for any of it.

Recovery if you ever flip it on by mistake:
1. Stop rdt-client: `docker compose stop rdt-client`
2. Wipe DB: `rm -rf config/rdt-client/*`
3. Wipe local files: `find /mnt/data/torrents/rdt-client/ -mindepth 1 -not -name tv-sonarr -not -name radarr -exec rm -rf {} +`
4. Restart and re-do the steps above.

## 5. Connect from Sonarr / Radarr

In each *arr:

1. Settings → Download Clients → `+ Add` → qBittorrent
2. Fill in:
   - Host: `rdt-client`
   - Port: `6500`
   - Username / Password: the admin login you set in the first step
   - Category: `tv-sonarr` (Sonarr) / `radarr` (Radarr)
3. Test → Save.

### Priority (rdt-client primary, qBittorrent fallback)

If you also have qBittorrent configured as a download client, set rdt-client to the *lower* priority number (lower number = higher priority in *arr):

- rdt-client: priority **1** (primary — RD does the torrenting, no local IP exposure)
- qBittorrent: priority **25** (fallback — used only if rdt-client is disabled or returns an error)

This means new downloads default to RD, with qBittorrent as the legal-protection fallback for content RD can't cache.

## How it works

1. Sonarr/Radarr finds a release, sends the magnet to rdt-client (looks identical to talking to qBit)
2. rdt-client calls RD's API: "add this magnet"
3. RD downloads the torrent on their servers in Switzerland
4. rdt-client polls RD until it's cached, then downloads each file from RD's CDN over HTTPS to local disk
5. Sonarr/Radarr import the files from `/data/torrents/rdt-client/{category}/` into the media library

Download speed is limited by *your* internet down-speed, since the actual byte transfer is happening to your machine. RD's CDN is fast, so this is usually as fast as your link allows.

## Troubleshooting

- **Magnet stuck in "Downloading" on RD side but no local file appearing:** check `Provider:Default:OnlyDownloadAvailableFiles`. If true (default), rdt-client only downloads RD-cached files; uncached torrents sit until RD caches them. Set false to allow rdt-client to wait for RD to fetch uncached content.
- **Sonarr error "directory does not exist":** pre-create the category subdirs (see step 3 above).
- **Sonarr import fails after download:** check Sonarr → Settings → Media Management → Recycling Bin path. Failed imports often go to the bin instead of erroring loudly.
- **rdt-client logs:** `docker compose logs rdt-client --tail=50` — log level is set to Error by default. Bump to Debug (LogLevel = 1) in Settings → General if you need more.
