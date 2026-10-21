---
id: '261021-0ZG5RXH'
title: Add asa-guard hook blocking direct Apple Ads API calls
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.232449Z'
status: open
labels:
- feature
---


The asc skill relies on `asc-guard.sh` (`/Users/dom/Agents/Hooks/asc-guard.sh`, symlinked to `~/.claude/hooks/`), a PreToolUse hook that blocks Bash commands and WebFetch URLs mentioning the App Store Connect API host. Nothing guards `api.ads.apple.com` or Apple's token endpoint, so an agent could bypass `asa` with curl.

**Do:** add `/Users/dom/Agents/Hooks/asa-guard.sh` modeled on `asc-guard.sh`: block `api.ads.apple.com` and `appleid.apple.com/auth/oauth2/token` (not all of `appleid.apple.com`), with a message pointing to `asa` (`asa <METHOD> /v1/...`, `--paginate` for `.../query`). Symlink it into `~/.claude/hooks/` and register it in `~/.claude/settings.json` next to `asc-guard.sh`; the settings change needs Dominic's OK. Then mention the hook in the apple-ads skill like the asc skill does.
