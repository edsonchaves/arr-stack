# Unpackerr Setup

Unpackerr runs as a background service — no web UI. It polls Sonarr and Radarr for completed downloads and automatically extracts `.rar` / `.zip` archives so the *arr apps can import them.

## Config

All configuration is done via environment variables in the compose file. The API keys are pulled from `.env`:

| Variable | Value |
|----------|-------|
| `UN_SONARR_0_URL` | `http://sonarr:8989` |
| `UN_SONARR_0_API_KEY` | `SONARR_API_KEY` from `.env` |
| `UN_RADARR_0_URL` | `http://radarr:7878` |
| `UN_RADARR_0_API_KEY` | `RADARR_API_KEY` from `.env` |

No additional setup is needed once the API keys are in `.env`.

## Verify it's working

```bash
docker logs unpackerr
```

A healthy log shows connections to each *arr app:

```
[INFO] Sonarr: Connected to http://sonarr:8989 ...
[INFO] Radarr: Connected to http://radarr:7878 ...
```

When a download is extracted:

```
[INFO] Extracting: /data/torrents/some-show.rar
[INFO] Finished: /data/torrents/some-show.rar
```
