# Grocery Hub Setup

**URL (LAN):** `http://localhost:3100` · **URL (phones):** the `tailscale serve` HTTPS URL

Household shopping list, pantry, receipt import and spending. Source and image: [edsonchaves/grocery-hub](https://github.com/edsonchaves/grocery-hub) (`ghcr.io/edsonchaves/grocery-hub`, updated by Watchtower).

Data (SQLite DB + receipt files) lives in `${CONFIG_ROOT}/grocery-hub`.

## 1. Start

```bash
mkdir -p ~/nas-server/config/grocery-hub
docker compose up -d grocery-hub
docker compose ps grocery-hub   # should become "healthy"
```

The container runs as `USER_ID:GROUP_ID`, so the directory must belong to that user.

## 2. HTTPS for phones (Tailscale)

Installing the app on iOS and using the camera need HTTPS. `tailscale serve` provides it with a valid `*.ts.net` certificate, without opening any port to the internet.

On the host (once):

```bash
# Tailscale installed and logged in; MagicDNS + HTTPS certificates enabled in the admin console (DNS page)
sudo tailscale serve --bg --https=443 http://127.0.0.1:3100
tailscale serve status        # shows the https://<host>.<tailnet>.ts.net URL
```

Put that URL into `.env` and recreate the container:

```bash
GROCERY_HUB_PUBLIC_URL=https://<host>.<tailnet>.ts.net
docker compose up -d grocery-hub
```

Every household phone needs the Tailscale app, logged in to the same tailnet.

## 3. First run

1. Open the HTTPS URL → first visitor creates the household and becomes admin
2. **Mais/Settings → Gerar link de convite** → send the link to each member (single use, valid 7 days)
3. Each member opens the link on their phone, picks name + password, then installs the app:
   - iOS Safari: Share → *Add to Home Screen*
   - Android Chrome: menu → *Install app*
4. Each member can pick their language (PT / DE / EN) in Settings

## 4. Receipt reading

| Receipt | Needs |
|---|---|
| REWE eBon PDF (from the REWE app / e-mail) | nothing — parsed locally |
| Paper receipt photo, other PDFs | `ANTHROPIC_API_KEY` in `.env` (photos are sent to the Anthropic API) |
| No receipt (market stall etc.) | nothing — *Lançar compra manual* |

Recreate the container after changing `.env`: `docker compose up -d grocery-hub`.

## 5. Homepage widget

1. In the app (admin): **Settings → Widget token** → copy
2. `.env`: `GROCERY_HUB_WIDGET_TOKEN=<token>`
3. `docker compose up -d grocery-hub homepage`

The tile shows items on the list and spend this month.

## 6. Backup

SQLite runs in WAL mode — copying the files while the app writes can give a broken copy. Take an online snapshot first, then back up the directory as usual:

```bash
docker compose exec grocery-hub node -e \
  "require('better-sqlite3')('/data/grocery-hub.db').backup('/data/backup.db').then(() => console.log('ok'))"
```

`config/grocery-hub/backup.db` is then a consistent copy; the [README backup](../README.md#backup) tarball includes it.

**Restore:** stop the container, replace `grocery-hub.db` with `backup.db`, delete `grocery-hub.db-wal` and `grocery-hub.db-shm`, start again.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Login works on LAN but not via ts.net (or vice versa) | `GROCERY_HUB_PUBLIC_URL` must be exactly the `tailscale serve` URL |
| "Cross-site request forbidden" | Same as above — the request host must match the LAN host or the public URL |
| Photo receipts fail with "not configured" | `ANTHROPIC_API_KEY` missing |
| Widget shows an error | Token wrong or empty; check `curl -H "Authorization: Bearer <token>" http://localhost:3100/api/widget` |
