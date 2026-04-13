# Autoheal Setup

Autoheal runs as a background service — no web UI. It monitors all containers with a `healthcheck` defined and automatically restarts any that enter an `unhealthy` state.

## Config

No configuration required. The compose file sets `AUTOHEAL_CONTAINER_LABEL=all`, which means it watches every container that has a healthcheck, regardless of labels.

## Verify it's working

```bash
docker logs autoheal
```

A healthy log looks like:

```
Set AUTOHEAL_CONTAINER_LABEL to 'all'
Monitoring all containers with a health check
```

If a container was restarted, you'll see a line like:

```
Container /sonarr (abc123) found to be unhealthy - restarting container now with 10s timeout
```
