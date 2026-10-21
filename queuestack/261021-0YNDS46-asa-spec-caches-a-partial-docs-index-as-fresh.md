---
id: '261021-0YNDS46'
title: asa spec caches a partial docs index as fresh
author: Dominic Rodemer
created_at: '2026-10-21T08:43:25.969604Z'
status: open
labels:
- bug
---



`Docs.pages` (`src/asa/Classes/Docs.swift`) drops every page that fails to download, and `buildIndex` succeeds as long as one endpoint loaded. A network blip or 5xx during the index build writes an incomplete `index.json`, and `asa spec find` silently misses endpoints for 24h.

**Fix:** have `pages` report failures other than 404, and make `buildIndex` throw if any non-404 failure occurred. `index()` then falls back to the stale cached index and writes nothing.

**Test:** give `Docs` an injectable page loader and cover a partial failure: no index written, stale index returned.
