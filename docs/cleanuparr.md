# Cleanuparr Setup

**URL:** `http://localhost:11011`

Cleanuparr watches *arr queues and qBittorrent and cleans up stuck downloads, failed imports, malicious files, and finished/orphaned torrents. Configure it after the *arrs are running and qBit has a working WebUI.

> **First run:** on first visit you'll be asked to create a local admin account. If you don't see that screen, the auth state was bootstrapped from a previous install — stop the container, delete `config/cleanuparr/users.db*`, `config/cleanuparr/jwt-key.bin`, `config/cleanuparr/DataProtection-Keys/`, then restart.

## Required volume mount

For Unlinked Downloads (hardlink-based cleanup) to work, Cleanuparr needs filesystem access to the same paths qBit reports. The compose file mounts:

```yaml
volumes:
  - ${CONFIG_ROOT}/cleanuparr:/config
  - ${CONFIG_ROOT}/cleanuparr/logs:/var/logs
  - ${DATA_ROOT}:/data
```

Without `/data`, Unlinked Downloads silently does nothing.

## 1. Connect the apps

1. Settings → Download Clients → `+ Add` → qBittorrent
   - Host: `qbittorrent`
   - Port: `8080`
   - Username / Password: from `.env` (`QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD`)
   - Test → Save
2. Settings → Apps → `+ Add` once per *arr:

   | App | URL | API Key |
   |---|---|---|
   | Sonarr | `http://sonarr:8989` | Sonarr → Settings → General → Security |
   | Radarr | `http://radarr:7878` | Radarr → Settings → General → Security |

## 2. Queue Cleaner

Removes stuck or rejected items from the *arr queues and blocklists them so the same release isn't re-grabbed.

1. Settings → Queue Cleaner → set schedule to `Minutes / 5` (or `0 0/5 * * * ?` in advanced)
2. **Failed Import** — catches releases that fail at import (low CF score, "not an upgrade", samples). Configure:
   - Max Strikes: `3`
   - Skip if Not Found in Client: on
   - Pattern Mode: `Include`
   - Included Patterns (one per line):
     - `Not a Custom Format upgrade for existing`
     - `Not a quality upgrade for existing`
     - `Not an upgrade for existing`
     - `is a sample`
     - `Unable to determine if file is a sample`
     - `One or more episodes expected in this release were not imported`
     - `File is a sample`
3. **Stalled Downloads** → `+ Add Stall Rule` (one rule covers all):
   - Name: `All Stalled`
   - Privacy Type: `Both`
   - Min / Max Completion %: `0` / `100`
   - Max Strikes: `3`
   - Reset Strikes on Progress: on
4. **Downloading Metadata** — strikes magnets stuck in the DHT metadata-fetch phase. With the 5-min schedule, the default low strike count kills releases before slow magnets can resolve and blocklists them in the *arrs, causing a death loop where every alt-release of the same episode gets nuked in turn. Either:
   - Disable this rule (Stalled Downloads already catches torrents that connect but make no progress), **or**
   - Max Strikes: `12` (≈1 hour window, tolerant of low-seed / weak-DHT magnets)
5. Save Settings

## 3. Download Cleaner

Cleans up finished torrents based on ratio/seed time and orphaned torrents whose files were replaced by the *arrs.

1. Settings → Download Cleaner → enable, set schedule to `Hours / 1`
2. **Seeding Rules** → `+ Add Seeding Rule` for the standard cleanup:
   - Rule Name: `Standard cleanup`
   - Privacy Type: `Both`
   - Categories: `radarr`, `tv-sonarr`
   - Max Ratio: `2`
   - Min Seed Time: `24` hours
   - Max Seed Time: `168` hours (7 days)
   - Delete Source Files: on
3. **Seeding Rules** → `+ Add Seeding Rule` for the orphan cleanup:
   - Rule Name: `Unlinked cleanup`
   - Categories: `cleanup`
   - Max Ratio: `-1`
   - Min Seed Time: `0`
   - Max Seed Time: `1` hour
   - Delete Source Files: on

   > A torrent is removed when **both** the max ratio AND the min seed time are met, OR when the max seed time is reached regardless of ratio. `-1` disables a constraint.
4. **Unlinked Downloads** → enable. Detects torrents whose files have no remaining hardlink in the *arr libraries and moves them to a cleanup category so the Unlinked cleanup rule above can remove them.
   - Target Category: `cleanup` (must match the Unlinked cleanup rule)
   - Use Tag Instead: off
   - Download Directory / Local Directory: blank (paths match thanks to the `/data` mount)
   - Unlinked Categories: `radarr`, `tv-sonarr`
   - Save Unlinked Config

## 4. Malware Blocker / Content Blocker

Filters files inside torrents by filename pattern (samples, archives, executables).

1. Settings → Malware Blocker → enable, set schedule to `Minutes / 5`
2. Under **Arr Blocklists**, for each *arr:
   - Enabled: on
   - Blocklist Path: `https://cleanuparr.pages.dev/static/blacklist`
   - Blocklist Type: `Blacklist`
3. Save Settings

Available blocklist variants:

| URL | Use case |
|---|---|
| `…/static/blacklist` | Strict — recommended default; blocks samples + archive trojans |
| `…/static/blacklist_permissive` | Looser — only archive/executable patterns |
| `…/static/whitelist` | Only allows core video extensions |
| `…/static/whitelist_with_subtitles` | Allows video + subtitle extensions |

## 5. Blacklist Sync

Pushes the same blocklist into qBittorrent's native "Excluded file names" so qBit refuses matching files at the client level — defence-in-depth before the queue is involved. Hardcoded to hourly.

1. Settings → Blacklist Sync → enable
2. Blacklist File Path: `https://cleanuparr.pages.dev/static/blacklist`
3. Save Settings

> Replaces the older manual workflow of pasting the blocklist into qBit Settings → Downloads → Excluded file names.

## 6. Confirm job schedules

Each job has its own schedule field on its config page. After saving, Dashboard → Jobs shows `● Scheduled` with the next-run time. Expected state when everything above is done:

| Job | Cadence |
|---|---|
| Queue Cleaner | 5 min |
| Malware Blocker | 5 min |
| Download Cleaner | 1 h |
| Blacklist Sync | 1 h (locked) |
| Seeker | 10 min |
| CustomFormatScoreSyncer | Not Scheduled — disabled because [recyclarr](recyclarr.md) syncs custom formats instead |
