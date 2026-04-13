# Komga Setup

**URL:** `http://localhost:25600`

## First-time setup

1. On first launch Komga prompts you to create an admin account — set your email and password
2. After logging in, go to **Libraries** → **+ Add library**
3. Fill in:

   | Field | Value |
   |---|---|
   | Name | `Comics` |
   | Root folder | `/data/comics` (maps to `/mnt/data/media/comics` on your host) |

4. Click **Add** — Komga scans the folder and imports all series automatically

## Adding more libraries (optional)

If you store manga separately from western comics, add a second library pointing to a subfolder:

- Root folder: `/data/comics/manga` → Name: `Manga`
- Root folder: `/data/comics/western` → Name: `Comics`

## Reading settings

- Settings → **Reading direction** — set default to `Left to right` (western comics) or `Right to left` (manga)
- Per-series overrides are available from the series page → Edit metadata → Reading direction
