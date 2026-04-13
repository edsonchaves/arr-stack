# Homepage Setup

**URL:** `http://localhost:3090`

Homepage is mostly self-configuring. All services in `docker-compose.yml` already carry `homepage.*` labels, so their tiles and live widgets appear automatically once Homepage is running and the API keys are in `.env`.

## How auto-discovery works

Each service has labels like:

```yaml
labels:
  - homepage.group=Media
  - homepage.name=Sonarr
  - homepage.icon=sonarr.png
  - homepage.href=http://localhost:8989
  - homepage.widget.type=sonarr
  - homepage.widget.url=http://sonarr:8989
  - homepage.widget.key=${SONARR_API_KEY}
```

Homepage reads these from the Docker socket and builds the dashboard automatically. No manual tile configuration needed — just make sure all `*_API_KEY` variables are filled in `.env` and the stack is running.

## Config files

All config lives in `config/homepage/`. You can customize it, but the defaults work out of the box:

| File | Purpose |
|---|---|
| `settings.yaml` | Global settings — title, theme, background, search provider, weather |
| `services.yaml` | Manual tile definitions (auto-discovery via labels is preferred) |
| `widgets.yaml` | Top-bar widgets — date/time, weather, search bar |
| `bookmarks.yaml` | Quick-link groups (optional) |
| `docker.yaml` | Docker socket connection — pre-configured, do not change |

## Weather widget

To enable the weather widget in the top bar, fill in these variables in `.env`:

| Variable | Value |
|---|---|
| `HOMEPAGE_VAR_WEATHER_CITY` | Your city name (e.g. `São Paulo`) |
| `HOMEPAGE_VAR_WEATHER_LAT` | Latitude (e.g. `-23.55`) |
| `HOMEPAGE_VAR_WEATHER_LONG` | Longitude (e.g. `-46.63`) |
| `HOMEPAGE_VAR_WEATHER_UNIT` | `metric` or `imperial` |

Then restart Homepage: `docker compose restart homepage`

## Customizing the title and search

| Variable | Value |
|---|---|
| `HOMEPAGE_VAR_TITLE` | Browser tab title (e.g. `NAS`) |
| `HOMEPAGE_VAR_SEARCH_PROVIDER` | `google`, `duckduckgo`, `bing`, etc. |
| `HOMEPAGE_VAR_HEADER_STYLE` | `underlined`, `boxed`, `clean`, or `hidden` |
