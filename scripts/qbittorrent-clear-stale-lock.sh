#!/usr/bin/with-contenv bash
# Remove stale qBittorrent single-instance files left by an unclean shutdown
# (e.g. WSL2 idle-suspends and SIGKILLs Docker before qBittorrent can clean up).
# Without this, each respawned instance connects to the leftover ipc-socket,
# thinks another instance is already running, and exits -> s6 crash-loops it.
# Runs once at container start, before the qbittorrent service launches.
rm -f /config/qBittorrent/ipc-socket /config/qBittorrent/lockfile
echo "[init] cleared stale qBittorrent ipc-socket/lockfile (if any)"
