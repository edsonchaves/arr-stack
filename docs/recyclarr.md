# Recyclarr Setup

Recyclarr runs as a background service — no web UI. All configuration is done via config files. It syncs [TRaSH-Guides](https://trash-guides.info/) quality profiles and custom formats into Radarr and Sonarr.

## Config

1. Secrets — [config/recyclarr/secrets.yml](../config/recyclarr/secrets.yml):
   ```yaml
   sonarr_api_key: YOUR_SONARR_API_KEY
   radarr_api_key: YOUR_RADARR_API_KEY
   ```
2. Profiles + CFs — [config/recyclarr/recyclarr.yml](../config/recyclarr/recyclarr.yml). Inline comments explain each section.

## Common commands

All run inside the `recyclarr` container:

```bash
# Preview without applying (always run after a config edit)
docker compose exec recyclarr recyclarr sync --preview

# Apply
docker compose exec recyclarr recyclarr sync

# Adopt a profile/CF you created manually so Recyclarr can manage it
# (needed once if you want Recyclarr to take over an existing profile by name)
docker compose exec recyclarr recyclarr state repair --adopt

# List available TRaSH templates / profiles / CF groups
docker compose exec recyclarr recyclarr list quality-profiles radarr
docker compose exec recyclarr recyclarr list custom-format-groups sonarr
```

A successful run prints `✓ movies` and `✓ series` rows with non-error counts.

## Tip: keep your own custom formats alongside TRaSH

If you've added custom formats by hand in Radarr/Sonarr (e.g. subtitle/language preferences, accessibility flags) and want Recyclarr to leave them alone:

- Set `reset_unmatched_scores.enabled: false` on every `quality_profile` entry. The starter TRaSH templates set this to `true`, which would zero out the score of any CF not declared in your Recyclarr config — including your manual ones.
- Do not enable `delete_old_custom_formats: true` anywhere (default is already `false`).
- Verify with `recyclarr sync --preview` after any config change: your manual CFs should not appear in any "Score Updates" or "Custom Format / Action: Delete" table.

> **Note:** The `schedules` block was removed in newer Recyclarr versions — do not add it.

## CR Multi-Subs CF (added 2026-08-30)

Manual Sonarr CF `CR Multi-Subs` (+500 in `[Anime] Remux-1080p` only): matches
releases whose title has **both** a Crunchyroll source marker (`CR`,
`CrunchyRoll`) **and** a Multi-Subs pattern (two required
`ReleaseTitleSpecification` conditions — AND semantics; the Multi-Subs half is
the six regexes of the `Multi-Subs` CF collapsed into one alternation, since
only one non-required condition of a type needs to match otherwise).

Why: CR Multi-Subs releases (Erai-raws, ToonsHub CR) always embed a PT-BR sub
track, but scored 506 vs. subs-less Anime Web Tier 01 groups (FLE etc.) at
600, so Sonarr never swapped to the release that actually has Portuguese.
With +500 a CR Multi-Subs release scores ~1006: above every Anime Web tier
stack, still below Anime BD tiers (1000–1400), so BD upgrades stay possible.
This became the primary PT-BR path for airing anime after animetosho.org shut
down (2026-05-09) — Bazarr can no longer fetch embedded fansub subs for new
episodes.

Like the other manual CFs it is local (no trash_id) and survives syncs via
`reset_unmatched_scores: false`; it is listed in the safety comment block at
the top of `config/recyclarr/recyclarr.yml`.
