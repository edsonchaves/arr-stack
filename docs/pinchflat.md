# Pinchflat Setup

**URL:** `http://localhost:8945`

Pinchflat subscribes to YouTube channels and playlists and downloads new uploads automatically — laying them out as `Show/Season XX/SXXEYY - title.mp4` so Jellyfin treats them like a regular Sonarr-managed series.

**Use case in this stack:** dubbed-PT-BR series that only exist on YouTube (Bluey, Pokémon episode playlists, etc.). TVDB knows the show, Jellyfin matches the folder name, you get posters and metadata for free.

> **No VPN.** HTTPS to YouTube only. Runs on the normal `nas` network.

## How it lands on disk

- Container download dir: `/downloads`
- Host path: `/mnt/data/media/youtube-shows/`
- This is a **separate folder** from `/mnt/data/media/youtube/` (MeTube one-offs) and from `/mnt/data/media/tv/` (Sonarr-managed). Add it to Jellyfin as its own TV library.

## 1. First-run config

1. Open `http://localhost:8945/`
2. No login screen — Pinchflat trusts the local network. You're in.

## 2. Create a Media Profile

A Media Profile defines defaults (output template, format, subs, metadata) shared by every source. **The naming for TVDB-matched series is set per-source via an override**, not here — so this profile just needs sane defaults.

**Media Profiles → New**

| Field | Value |
|---|---|
| Name | `TV Shows` |
| Output path template | `/shows/{{ source_custom_name }}/{{ season_by_year__episode_by_date_and_index }} - {{ title }}.{{ ext }}` |
| Format preference | `1080p` (or whatever balances quality vs. disk) |
| Download subs | `On`, languages: `en,pt`, embed: yes |
| Download metadata | `On` (writes NFO + thumbnail for Jellyfin) |
| Redownload deleted | `Off` (otherwise it re-fetches what you delete) |

Save.

> The default `season_by_year__episode_by_date_and_index` variable groups episodes by *upload year*, which is fine for random YouTubers but **wrong for real shows** (Pokémon S1 was aired in 1997 but uploaded in 2024). For TVDB-matched series, you'll override this per source — see Step 3.

## Shortcut: bulk-add via helper script

For a series with multiple season playlists, [`scripts/pinchflat-add-series.sh`](../scripts/pinchflat-add-series.sh) automates step 3 below. It submits the HTML form with all the right defaults (override template, `fast_index=false`, correct `media_playlist_index` variable) and triggers a slow re-index, so you skip the UI clicks.

```bash
./scripts/pinchflat-add-series.sh "Bluey" <<EOF
1 https://www.youtube.com/playlist?list=PL...
2 https://www.youtube.com/playlist?list=PL...
EOF
```

Reads `<season> <playlist_url>` lines from stdin until EOF. First arg is the TVDB title (becomes the folder name). Second arg is optional media-profile id (default `2`).

## 3. Add a Source (one per season playlist)

For a real TV series (Bluey, Pokémon, etc.) you'll add **one Pinchflat source per season's playlist** and hard-code the season number in the path template override.

**Sources → New Source**

| Field | Value |
|---|---|
| Source URL | The YouTube playlist URL for that season |
| Media profile | `TV Shows` |
| Custom name | Exact TVDB title (e.g. `Pokémon`, `Bluey`) — controls the show folder name |
| Output path template override | `/shows/<TVDB title>/Season XX/SXXE{{ media_playlist_index }} - {{ title }}.{{ ext }}` — with `XX` hardcoded to that season's number (e.g. `01`, `02`, ...) |
| Fast indexing | **OFF** — see warning below |
| Download cutoff date | Blank to grab everything; set a date for a backlog limit |

Save → Pinchflat indexes the playlist and queues downloads.

> **Concrete example** — Pokémon Season 3:
> - Custom name: `Pokémon`
> - Override: `/shows/Pokémon/Season 03/S03E{{ media_playlist_index }} - {{ title }}.{{ ext }}`
> - Files land at: `/mnt/data/media/youtube-shows/shows/Pokémon/Season 03/S03E01 - Don't Touch That 'Dile!.mp4`

> **Why `media_playlist_index` and not something else?** That's the literal Pinchflat variable name for "this video's position in the playlist, padded to 2 digits." Made-up variables silently pass through to yt-dlp and return `NA`, producing files named `S03ENA - ...`. Source: [`download_option_builder.ex:211`](https://github.com/kieraneglin/pinchflat/blob/master/lib/pinchflat/downloading/download_option_builder.ex#L211).

> **Why fast indexing OFF?** Fast mode uses yt-dlp's `--flat-playlist` which can silently leave `playlist_index = 0` for a chunk of items on some playlists (we saw this on Pokémon Seasons 2, 3, and 8). The result is everything named `SXXE00`, which Jellyfin can't disambiguate. Slow indexing (1-2 min per source) gets it right.

> **TVDB naming hint:** open the show on [thetvdb.com](https://thetvdb.com) and use that exact title as the Custom Name. Jellyfin matches the folder name against TVDB — get it right and metadata pulls in clean.

## 4. Add the folder to Jellyfin

1. Jellyfin → Dashboard → Libraries → **Add Media Library**
2. Type: **Shows**
3. Display name: `YouTube Shows` (or merge with your main TV library if you don't mind them mixed — see below)
4. Folder: `/data/media/youtube-shows`
5. Metadata downloaders: TheTVDB on, TheMovieDb on
6. Save → scan

After the scan, Bluey / Pokémon / etc. appear in Jellyfin with full posters, summaries, and episode lists.

### Should I merge with my main TV library?

Two options:

| Approach | Folder | Pros | Cons |
|---|---|---|---|
| **Separate library** | Add `youtube-shows` as its own Jellyfin library | Clean separation; easy to see what came from where | Bluey shows up in two places if Sonarr also picks it up later |
| **Same TV library** | Add `youtube-shows` as a second folder on your existing TV library | Unified browse experience | Episodes from YouTube and Sonarr mix into the same season — fine if seasons don't overlap |

For dub-only PT-BR content that Sonarr can't grab (no proper releases exist), the **same TV library** option is usually nicer. Just add the folder to the existing library's "Folders" list.

## 5. Watching for new episodes

Pinchflat re-checks every source on a schedule (default: every 24h). You can:
- Force a check: source page → **Tasks → Check for new media**
- Change the schedule: **Settings → Tasks**

New uploads download automatically into the existing `Show/Season XX/` folder using the next playlist index.

## 6. After any disk wipe / template change — reconcile

If you ever delete files manually, change a source's template override, or otherwise get the DB out of sync with what's on disk, Pinchflat will keep insisting "everything's downloaded" because the DB still has the old `media_filepath` values. The fix is two clicks per source:

1. Source page → **Tasks → Sync files on disk** — Pinchflat walks the disk, marks missing files as not-downloaded.
2. Same page → **Tasks → Force redownload** — re-queues everything for the source with the *current* template.

If you've also fixed broken `playlist_index` values (deleted rows directly in `config/pinchflat/db/pinchflat.db`), run **Tasks → Force index** first so the missing rows come back.

## Troubleshooting

- **"Sign in to confirm you're not a bot"** — YouTube wants cookies. Export your browser cookies as `cookies.txt`, put it at `config/pinchflat/cookies.txt`, then **Settings → Cookies file → /config/cookies.txt**.
- **Wrong show in Jellyfin** — your **Custom name** doesn't match TVDB. Open the show on thetvdb.com, copy the exact title, edit the source, then **Tasks → Rename existing media** to re-organize.
- **Files named `SXXENA` or `SXXE00`** — template variable broken. Check the source's override uses `{{ media_playlist_index }}` (not `media_index_padded`, `episode_index_padded`, or anything else — those don't exist and produce `NA`). Also confirm **Fast indexing is OFF**: with it on, some playlists end up with `playlist_index=0` in the DB and you'll get `E00` everywhere. Recovery: delete the affected rows from the DB (`DELETE FROM media_items WHERE playlist_index=0`), then Tasks → Force index, then Tasks → Force redownload.
- **DB query needs FTS5** — Pinchflat's schema uses FTS5 virtual tables. Most lightweight `sqlite3` images don't include FTS5 and choke on `.schema`. Use Python instead: `docker run --rm -v ~/nas-server/config/pinchflat/db:/db python:3-alpine python -c "import sqlite3; ..."` — system libsqlite3 has FTS5 built in.
- **Pinchflat says downloaded but Jellyfin sees nothing** — disk and DB are out of sync. See **Section 6 — reconcile**.
- **Old yt-dlp blocked by YouTube** — image is rebuilt regularly. Watchtower will pull updates; force one with `docker compose pull pinchflat && docker compose up -d pinchflat`.
- **Permissions errors** — confirm `/mnt/data/media/youtube-shows/` is owned by your `USER_ID:GROUP_ID`. Fix: `sudo chown -R $USER:$USER /mnt/data/media/youtube-shows`.
- **Logs** — `docker compose logs pinchflat --tail=100`. Set `LOG_LEVEL=debug` in compose for more.

## Available template variables (verified)

These work in `output_path_template` and `output_path_template_override`. Anything else falls through to yt-dlp untouched (and most things you'd guess return `NA`).

| Variable | Value |
|---|---|
| `{{ source_custom_name }}` | The Custom Name field on the source |
| `{{ media_playlist_index }}` | Position in the playlist, zero-padded to 2 digits |
| `{{ media_upload_date_index }}` | Index based on upload date (alternative to playlist position) |
| `{{ title }}` | The video title from YouTube |
| `{{ ext }}` | The file extension (`mp4`, `webm`, etc.) |
| `%(upload_date>%Y)S` | yt-dlp pass-through — e.g. `2024`. Any single-word `%(field)S` works. |

Source: [`output_path_builder.ex:51-66`](https://github.com/kieraneglin/pinchflat/blob/master/lib/pinchflat/downloading/output_path_builder.ex#L51-L66).
