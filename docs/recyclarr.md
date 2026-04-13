# Recyclarr Setup

Recyclarr runs as a background service — no web UI. All configuration is done via config files.

## Config

Edit [config/recyclarr/recyclarr.yml](../config/recyclarr/recyclarr.yml):

1. Create `config/recyclarr/secrets.yml` with:
   ```yaml
   sonarr_api_key: YOUR_SONARR_API_KEY
   radarr_api_key: YOUR_RADARR_API_KEY
   ```
2. Uncomment the quality profiles you want in `recyclarr.yml`
3. Test: `docker compose exec recyclarr recyclarr sync` — a successful run shows `✓ movies` and `✓ series` with quality sizes synced

> **Note:** The `schedules` block was removed in newer Recyclarr versions — do not add it.
