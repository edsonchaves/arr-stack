# Bazarr Setup

**URL:** `http://localhost:6767`

1. Settings → General → Security → Authentication → enable `Form` login, set username and password
2. Settings → Sonarr → URL: `http://sonarr:8989`, API key from Sonarr
3. Settings → Radarr → URL: `http://radarr:7878`, API key from Radarr
4. Settings → Languages:
   1. **Languages Filter** → search for and add `Portuguese (Brazil)` — this enables it in the system and unlocks the profile creation button
   2. **Languages Profile** → click `+` to create a new profile → name it `PT-BR` → click `+ Language` → fill in:
      - Language: `Portuguese (Brazil)`
      - Subtitles Type: `Normal or hearing-impaired` (downloads any subtitle — "Hearing-impaired" adds sound descriptions like `[door slams]`, "Forced" is only for foreign-language scenes)
      - Search only when: `Always` (other options: `audio track matches` = only search when audio is also in that language; `no audio track matches` = only search when there's no native audio in that language — useful if you want subtitles only for dubbed content)
      - Cutoff: leave empty (Bazarr always searches for the best match)
      - Must contain: leave empty for now — if you later get European Portuguese instead of Brazilian, add `BR` here
      - Must not contain: leave empty
      - Use Original Format: off (keeps subtitles as .srt, which is more compatible with Jellyfin)
      → Save
   3. **Default Language Profiles For Newly Added Shows** → enable the **Series** toggle → select `PT-BR` → enable the **Movies** toggle → select `PT-BR`
   4. Hit Save at the top
5. Settings → Providers → Add subtitle providers. Start with these (account needed):
   - **Legendas.net** — Brazilian Portuguese focused
   - **OpenSubtitles.com** — Large general library

> **Save to `.env`:** Settings → General → Security → copy the API Key → paste as `BAZARR_API_KEY` in `.env`

## PT-BR re-search bridge (Sonarr upgrade loop)

Bazarr retries subtitle providers on its own, but for **anime** the PT-BR sub
usually ships *embedded* in a later release (ToonsHub/CR `Multi-Subs`) rather
than appearing on Legendas.net/OpenSubtitles — and Sonarr never re-searches an
episode it already downloaded, so an English-only fansub grab (Asakura,
SubsPlease, FLE…) stays forever.

Bridge: `scripts/sonarr-research-missing-ptbr.sh` (cron, daily 06:15)

1. Reads Bazarr's wanted list (episodes still missing PT-BR)
2. Filters to episodes aired in the last 45 days, caps at 20 per run
3. Triggers a Sonarr `EpisodeSearch` — upgrade-only, since `Subs PT-BR`
   (+1000) and `Multi-Subs` (+200) CFs outscore the current file and cutoff
   score is 10000 (never met)
4. Self-terminating per episode: once a PT-BR sub exists (embedded or
   downloaded by Bazarr), it leaves the wanted list and stops being searched

Log: `logs/sonarr-research-ptbr.log`

Known gaps this can't fix:
- **AMZN-only titles not licensed in Brazil** (e.g. False Memory): no PT
  track exists at the source; only a human upload to Legendas.net helps.
  (Verified 2026-08-30: the AMZN "Multi-Subs" release carries eng/ger/ind/
  rus/tha and the BILI release only eng/tha — "Multi-Subs" in a title does
  NOT guarantee PT-BR; only CR-source Multi-Subs does.)
- `legendasdivx` provider has broken credentials (AuthenticationError,
  12h throttle) — PT-PT anyway; fix or remove in Settings → Providers.

## AniDB client + animetosho status (2026-08-30)

Settings → Providers → AniDB is filled with HTTP API client `<your-client-name>` / ver 1
(registered at anidb.net → software → your project; the client string is
the lowercase per-client name, NOT the project name — AniDB answers error 302
"client version missing or invalid" for any wrong name/case/type). This makes
the AniDB refiner map Sonarr episodes to AniDB episode ids, which the
animetosho provider needs.

**However animetosho.org shut down permanently on 2026-05-09** (official
notice; frozen archive until ~Oct 2026). The provider still serves embedded
subs for pre-May-2026 anime, nothing after. No Bazarr provider exists yet for
the successors (ameNZB, Anime Tosho NEW, aninzb, TsukiHime, Otakuness) — check
periodically. Until then, PT-BR for airing anime comes from Sonarr grabbing
CR Multi-Subs releases directly (see `CR Multi-Subs` CF note in
`config/recyclarr/recyclarr.yml` and docs/recyclarr.md).

## Minimum score (lowered 2026-08-30)

Settings → Subtitles → minimum score for series was **90**, which silently
discarded real matches (Rick and Morty PT-BR found at 61–69 and rejected).
Lowered to **65** (movies were already 70). Trade-off: occasional out-of-sync
subtitle; Bazarr's upgrade loop can replace them later.
