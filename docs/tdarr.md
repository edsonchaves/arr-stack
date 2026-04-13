# Tdarr Setup

**URL:** `http://localhost:8265`

## Library

1. Click the **Libraries** tab → **+ Add Library**
2. Fill in:

   | Field | Value |
   |---|---|
   | Library Name | `Media` |
   | Source | `/media` (maps to `/mnt/data/media` on your host) |
   | Transcode Cache | `/temp` (mounted from `/tmp/tdarr_transcode_cache` on the host — where files are stored mid-transcode) |
   | Output | `/media` (same path = in-place transcoding, replaces original) |

## Plugin stack

Click the **Transcode Options** tab → make sure **Classic Plugin Stack** is toggled on. Build the plugin stack by dragging plugins from the right panel into the center stack. Recommended stack order:

| Order | Plugin | Settings |
|---|---|---|
| 1 | `Community: Filter By Codec` | codecsToProcess: empty — codecsToNotProcess: `hevc` (skips files already in H.265) |
| 2 | `Migz Remove Image Formats From File` | default settings |
| 3 | `Lmg1 Reorder Streams` | default settings |
| 4 | `Migz Transcode Using Nvidia GPU & FFMPEG` | Enabled: ✅ — container: `mkv` — enable_10bit: `true` — rest: default |
| 5 | `New File Size Check` | rejects output if larger than original |

> **Note:** This plugin stack is specific to Nvidia GPUs (uses NVENC). If you don't have an Nvidia GPU, replace plugin 4 with a CPU-based H.265 transcode plugin.

## Auto-accept and nodes

1. On the **Home** page → scroll to the bottom → **Staging Section** → check **Auto accept successful transcodes**
2. Click **MainNode** in the Nodes section → set workers:
   - Transcode CPU: `0` (not using CPU)
   - Transcode GPU: `1` (or `2` max — each worker = one parallel GPU transcode job)
   - Health Check CPU: `1` (optional — verifies file integrity after transcoding)
   - Health Check GPU: `0`
