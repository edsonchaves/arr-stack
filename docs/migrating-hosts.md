# Moving the stack to another host

Container-side paths (`/config`, `/data`) never change, so no *arr root
folder, Jellyfin library or qBittorrent save path needs editing. Only
host-side values move: `.env`, and the GPU override chosen by `COMPOSE_FILE`.

## New host

1. Create the main user with the **same UID/GID** as `USER_ID`/`GROUP_ID`
   in `.env` (first user on Ubuntu = 1000). Different IDs mean a `chown -R`
   over the whole library.
2. Give the box a fixed LAN IP (DHCP reservation).
3. Ubuntu Server: `sudo bash scripts/bootstrap-ubuntu-host.sh`. Installs
   Docker from the official repo, enables it at boot, sets timezone, adds
   the i915 GuC/HuC option Alder Lake-N iGPUs need, and creates `/mnt/data`.
   Other distros: do the same by hand.
4. Keep `media/` and `torrents/` on one filesystem so hardlinks work. If
   `/mnt/data` is a separate disk, mount it by UUID with `nofail` and add
   `RequiresMountsFor=/mnt/data` to `docker.service` (the bootstrap script
   does this).

## Copy — two passes

Pass 1 with the old stack still running, pass 2 with it stopped. Downtime
is the delta only.

```bash
NEW=<new-host>

# Pass 1 — bulk media, stack up
rsync -aH --info=progress2 --numeric-ids /mnt/data/media/ $NEW:/mnt/data/media/

# Cutover
docker compose down

# Pass 2 — delta + runtime state. config/ has root-owned dirs (postgres) → root on both ends
rsync -aH --delete --numeric-ids /mnt/data/media/    $NEW:/mnt/data/media/
rsync -aH --delete --numeric-ids /mnt/data/torrents/ $NEW:/mnt/data/torrents/
sudo rsync -aH --delete --numeric-ids --rsync-path="sudo rsync" \
  ~/nas-server/ $NEW:~/nas-server/
```

`.env` is not in git — the last command is its only copy. Verify it arrived.

## `.env` on the new host

| Key | Set to |
|---|---|
| `COMPOSE_FILE` | `docker-compose.yml:docker-compose.intel.yml` (or `nvidia-wsl`) |
| `RENDER_GID` | `getent group render \| cut -d: -f3` (Intel only) |
| `SERVER_LAN_IP` | new LAN IP |
| `HOMEPAGE_ALLOWED_HOSTS` | add `<ip>:3090` |

## First start

```bash
docker compose pull && docker compose up -d && docker compose ps
```

1. `docker logs vpn` shows the VPN connected.
2. qBittorrent: torrents present, none "Missing files".
3. Sonarr/Radarr → System → Health clean; Prowlarr app sync test OK.
4. Jellyfin: play a file that needs transcoding and check `docker logs
   jellyfin` for `_qsv` (or `_nvenc`). Set hardware acceleration per
   `docs/jellyfin.md`.
5. Homepage opens on the new IP without "Host not allowed".
6. Re-add host cron jobs (`scripts/`).
7. Reboot once. Everything must come back on its own.

## Cutover

- Point clients (Jellyfin TV app) at the new IP. Users, watch state and
  Jellystat history travel in `config/`.
- Do not run both stacks at once: two Sonarr instances grab the same
  releases. The old host is the rollback until you delete it.
