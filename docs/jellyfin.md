# Jellyfin Setup

**URL:** `http://localhost:8096`

The first launch runs a setup wizard:

1. **Server name** — change from the default container ID to something readable like `NAS`
2. **Preferred display language** — set to `Português (Brasil)` if desired → Next
3. **Create admin account** — set your username and password → Next
4. **Add Media Libraries** — add one library for each media type. For each one click `+` and fill in:

   | Field | Movies | TV Shows | Music |
   |---|---|---|---|
   | Content type | `Movies` | `Shows` | `Music` |
   | Display name | `Movies` | `TV Shows` | `Music` |
   | Folders | `/data/media/movies` | `/data/media/tv` | `/data/media/music` |
   | Preferred metadata language | your preference (e.g. `English`) | same | same |
   | Preferred metadata country | your preference (e.g. `United States`) | same | — |
   | Everything else | leave as defaults | leave as defaults | leave as defaults |

   The metadata fetchers (TMDb for movies, TheTVDB for shows, MusicBrainz for music) are pre-selected and correct — do not change them.

5. **Allow remote connections** — enable this. When you connect via WireGuard VPN, your device gets a VPN IP that Jellyfin sees as remote — disabling this would block those devices. Since there is no port forwarding set up, the internet cannot reach Jellyfin directly regardless of this setting.

## Hardware transcoding

Which backend applies depends on the compose override selected via `COMPOSE_FILE` in `.env` (see README → GPU passthrough).

**Intel QSV** (`docker-compose.intel.yml`, i3-N305 iGPU):
- Admin Dashboard → Playback → Transcoding:
  - Hardware acceleration → `Intel QuickSync (QSV)`
  - QSV device → `/dev/dri/renderD128`
  - Enable hardware decoding for: check `H264`, `HEVC`, `HEVC 10bit`, `VP9`, `AV1`
  - Enable hardware encoding → on; Allow encoding in HEVC format → on
  - Enable Intel Low-Power H.264/HEVC hardware encoder → on (mandatory on Alder Lake-N — the iGPU has no full-power encoder)
  - Save

**Nvidia NVENC** (`docker-compose.nvidia-wsl.yml`):
- Admin Dashboard → Playback → Transcoding:
  - Hardware acceleration → `Nvidia NVENC`
  - Enable hardware decoding for: check `H264`, `HEVC`, `VC1`, `VP9`, `HEVC 10bit`, `VP9 10bit` (enable `AV1` too if you have an RTX 30xx or newer)
  - Enable enhanced NVDEC decoder → on
  - Enable hardware encoding → on
  - Save

## Plugins

- Admin Dashboard → Plugins → Catalog → install extras as desired (popular: **Trakt** for scrobbling watch history)

> **Save to `.env`:** Admin Dashboard → API Keys → click `+` → name it `homepage` → copy the generated key → paste as `JELLYFIN_API_KEY` in `.env`. This key is used by Homepage (live stats widget) and Jellystat (watch history) — it is separate from your username/password login.
