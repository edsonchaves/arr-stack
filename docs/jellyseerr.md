# Jellyseerr Setup

**URL:** `http://localhost:5055`

1. On first launch select **Jellyfin** as the server type before connecting
2. Fill in the sign-in form:

   | Field | Value |
   |---|---|
   | Jellyfin URL | `jellyfin` (`http://` prefix is already shown, port is a separate field) |
   | Port | `8096` |
   | Use SSL | off |
   | URL Base | leave empty |
   | Username | your Jellyfin admin username |
   | Password | your Jellyfin admin password |

3. After signing in, on the Jellyfin settings page:
   - **Sync Libraries** → click it to import your Jellyfin libraries (Movies, TV Shows, Music) into Jellyseerr
   - **API Key** — auto-generated, no action needed
   - **External URL** — leave empty for now (fill in later if you add a domain and reverse proxy)
   - **Forgot Password URL** — leave empty
   - Save Changes
4. Connect to Sonarr: host `sonarr`, port `8989` and Radarr: host `radarr`, port `7878` with their API keys
5. Set request permissions for your users

> **Save to `.env`:** Settings → General → copy the API Key → paste as `JELLYSEERR_API_KEY` in `.env`
