---
id: '261021-0ZG5S9H'
title: Add asa spec status [--check]
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.132901Z'
status: open
labels:
- feature
---



`asc spec status [--check]` shows the cached spec and forces a refresh. `asa` has no way to see the docs index age or endpoint count, or to force a refresh; the only option is deleting `~/Library/Caches/asa/docs`.

**Do:** add `asa spec status [--check]` printing the index's endpoint count and when it was built, with `--check` rebuilding the index now. Mirror asc's output layout. Update the usage text, README and the apple-ads skill.
