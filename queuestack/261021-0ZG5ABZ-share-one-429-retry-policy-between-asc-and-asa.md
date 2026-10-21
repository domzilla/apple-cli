---
id: '261021-0ZG5ABZ'
title: Share one 429 retry policy between asc and asa
author: Dominic Rodemer
created_at: '2026-10-21T08:57:41.121909Z'
status: open
labels:
- refactoring
---



Both `src/asc/Classes/APIClient.swift` and `src/asa/Classes/APIClient.swift` have their own retry loop for 429s, with different policies: asc waits `Retry-After` or `2^n` with no cap, asa also reads `RateLimit-Reset` and caps the wait.

**Do:** move the retry delay (and ideally the 429 loop) into AppleCLIKit with one policy: honor `Retry-After`, fall back to `RateLimit-Reset`, else exponential backoff capped at 16s. Fix bug "asa caps Retry-After at 16 seconds" in the same change. Cover the shared policy with tests in AppleCLIKitTests.
