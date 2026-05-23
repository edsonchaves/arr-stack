# Maintainerr Setup

**URL:** `http://localhost:6246`

1. Settings → connect to Jellyfin (`http://jellyfin:8096`), Sonarr (`http://sonarr:8989`), Radarr (`http://radarr:7878`) with their API keys
2. Optional: connect Jellyseerr so pending requests can be excluded from rules
3. Create Rule Groups (recipes below). Each rule group becomes a Jellyfin collection of "items scheduled for deletion"; the configured `*arr action` (e.g. Radarr → Delete) runs once an item has sat in the collection longer than `Take action after days`.

## Concepts

- **Rule Group** = one library + one set of rules + one delete action. Becomes a Jellyfin collection.
- **Rules** match items into the group. Combined with AND/OR.
- **Take action after days** = grace period the item stays in the collection (with a date overlay on the poster) before the *arr action fires. Stacks on top of any time-based rule.
- **Add import list exclusions** = ON prevents Sonarr/Radarr import lists (Trakt, etc.) from re-grabbing whatever you just deleted.

## Movies — watched & stale

Rule Group Settings:

| Field | Value |
|-------|-------|
| Name | `Movies — watched & stale` |
| Library | (your Jellyfin Movies library) |
| Radarr server | `radarr` |
| Radarr action | `Delete` |
| Take action after days | `30` |
| Active | ✅ |
| Enable overlays | ✅ |
| Add import list exclusions | ✅ |
| Force delete Seerr request | ❌ |
| Use rules | ✅ |

Rules (all ANDed):

| # | First Value | Action | Second Value | Custom Value |
|---|-------------|--------|--------------|--------------|
| 1 | `Jellyfin - Times viewed` | `Bigger` | `Number` | `1` |
| 2 | `Jellyfin - Last view date` | `After` | `Amount of days` | `14` |

Effect: movie has ≥ 2 plays AND last view was > 14 days ago → enters collection → deleted after 30 more days (total ≈ 44d from last view).

## TV — watched & stale (per season)

Rule Group Settings: same as Movies, but:

| Field | Value |
|-------|-------|
| Name | `TV — watched & stale` |
| Library | (your Jellyfin TV/Shows library) |
| Sonarr server | `sonarr` |
| Sonarr action | `Delete` |

If a **Data type** / level picker is shown, choose **Seasons** — episode-level creates gaps mid-season, show-level keeps too much around.

Rules (all ANDed):

| # | First Value | Action | Second Value | Custom Value |
|---|-------------|--------|--------------|--------------|
| 1 | `Jellyfin - [list] Users that watched every episode` | `Count Is Bigger Than` | `Count (number)` | `0` |
| 2 | `Jellyfin - Newest episode view date` | `After` | `Amount of days` | `14` |
| 3 | `Sonarr - Has unaired episodes` | `Equals` | `Boolean` | `false` |

Effect: at least one user finished every episode in the season AND no playback for 14d AND the whole season has aired → enters collection → deleted after 30 more days.

Why "watched every episode" (not "Total views > 1"): TV's equivalent of the movie "≥2 plays" rule. If someone fell asleep on E04, the season isn't complete and won't qualify — no false-positive deletions.

## Tuning later

- Want a tighter loop? Drop **Take action after days** from `30` to `7` (total ≈ 21d from last view).
- Want to protect ongoing/anime watchlists? Keep them in a separate Jellyfin library and don't add a rule group for it.
- Want to be stricter on movies? Bump Rule #1 to `Bigger 1` → ≥ 2 plays.

## Troubleshooting

- **Nothing gets deleted**: Settings → test connections for Jellyfin/Sonarr/Radarr. Check the schedule (Settings → Maintenance) runs more often than your shortest grace period.
- **Rule list returns `[]` via API**: rules must be saved *and* the group has to be Active.
