# Sonarr / Radarr / Lidarr Setup

**URLs:**
- Sonarr: `http://localhost:8989`
- Radarr: `http://localhost:7878`
- Lidarr: `http://localhost:8686`

Do these steps for each app individually.

## Authentication

1. Settings → General → show Advanced (toggle at top)
2. Authentication → `Forms (Login Page)`
3. Set a username and password → Save

## Media root folder

This tells each app where to store the final media files after download. The path must match the volume mounted inside the container (`/data` maps to `/mnt/data` on your host).

**Sonarr** and **Radarr:**
1. Settings → Media Management → Root Folders → + Add Root Folder
2. Path: `/data/media/tv` (Sonarr) or `/data/media/movies` (Radarr) → Save

**Lidarr** has extra fields when adding a root folder:
1. Settings → Media Management → Root Folders → + Add Root Folder
2. Fill in:

   | Field | Value | Notes |
   |---|---|---|
   | Name | `Music` | just a label |
   | Path | `/data/media/music/` | |
   | Monitor | `All Albums` | monitors all existing albums for any artist added from this folder |
   | Monitor New Albums | `All Albums` | automatically monitors new releases from followed artists |
   | Quality Profile | `Any` | change later once you know your preferred quality |
   | Metadata Profile | `Standard` | includes studio albums only — excludes singles, bootlegs, remixes |
   | Default Lidarr Tags | leave empty | |

3. Save

If any folder shows an error (not green), the directory doesn't exist on the host yet:
```bash
sudo mkdir -p /mnt/data/media/{tv,movies,music}
sudo chown -R $USER:$USER /mnt/data/media
```

## Download client

1. Settings → Download Clients → + Add
2. Select `qBittorrent`
3. Fill in:
   - Host: `vpn` (not `qbittorrent` — qBittorrent shares the VPN container's network)
   - Port: `8080`
   - Username and Password: your qBittorrent credentials
   - Category: `tv-sonarr` (Sonarr) / `radarr` (Radarr) / `lidarr-music` (Lidarr)
4. Test → Save

> **Save to `.env`:** While in each app, go to Settings → General → Security → copy the API Key and paste into `.env`:
> - Sonarr → `SONARR_API_KEY`
> - Radarr → `RADARR_API_KEY`
> - Lidarr → `LIDARR_API_KEY`
