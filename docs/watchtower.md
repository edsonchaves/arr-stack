# Watchtower Setup

Watchtower runs as a background service — no web UI. It polls Docker Hub and container registries for newer image versions and automatically pulls and restarts containers when updates are available. Old images are cleaned up after each update (`WATCHTOWER_CLEANUP=true`).

## Config

No configuration required. By default Watchtower checks for updates once every 24 hours.

## Verify it's working

```bash
docker logs watchtower
```

A healthy log looks like:

```
time="..." level=info msg="Watchtower 1.x.x"
time="..." level=info msg="Starting Watchtower and scheduling first run"
```

When an update is applied:

```
time="..." level=info msg="Found new ghcr.io/... image"
time="..." level=info msg="Stopping /sonarr (abc123) with grace timeout 30 seconds"
time="..." level=info msg="Creating /sonarr"
time="..." level=info msg="Removing image ..."
```
