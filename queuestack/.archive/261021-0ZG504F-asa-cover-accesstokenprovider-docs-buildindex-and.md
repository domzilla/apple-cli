---
id: '261021-0ZG504F'
title: 'asa: cover AccessTokenProvider, Docs.buildIndex and the 401 retry'
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.186174Z'
status: closed
labels:
- test
---


Untested logic:
- `AccessTokenProvider`: caching, the 60s refresh margin, one shared fetch for concurrent callers, invalidation. Inject the fetch closure (default `AccessToken.fetch`) so it's pure logic.
- `Docs.buildIndex`: topic → endpoint page discovery, including partial failure (see bug "asa spec caches a partial docs index as fresh"). Needs an injectable page loader.
- The 401 → new token → single retry in `APIClient.send`. Needs an injectable transport, or at least test the decision logic separately.

No test may reach the network.
