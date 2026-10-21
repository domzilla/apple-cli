---
id: '261021-0YNE8DS'
title: asa concurrent 401s can invalidate a freshly refreshed token
author: Dominic Rodemer
created_at: '2026-10-21T08:43:26.035240Z'
status: open
labels:
- bug
---



`AccessTokenProvider.invalidate()` (`src/asa/Classes/AccessTokenProvider.swift`) clears the cache unconditionally. When several requests get a 401 at once, a late `invalidate()` can drop the token another request just fetched, causing extra token requests.

**Fix:** `invalidate(_ rejected: String)` clears the cache only if the cached value is the rejected token. `APIClient.send` passes the token it sent.

**Test:** inject the fetch closure into `AccessTokenProvider` and cover caching, the refresh margin, a shared concurrent fetch, and that invalidating an older token keeps the current one.
