# Uptime Kuma Setup

**URL:** `http://localhost:3001`

1. Create an admin account on first launch
2. Add Monitor → HTTP(s) → one per service:
   - Name: `Sonarr` — URL: `http://localhost:8989` — repeat for each service
3. Set up a notification channel (Telegram, Discord, email) so you get alerted when a service goes down
