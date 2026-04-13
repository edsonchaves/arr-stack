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
