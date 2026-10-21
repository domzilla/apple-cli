---
id: '261021-0YNDBD9'
title: asa caps Retry-After at 16 seconds
author: Dominic Rodemer
created_at: '2026-10-21T08:43:25.989708Z'
status: closed
labels:
- bug
---


`APIClient.retryDelay` (`src/asa/Classes/APIClient.swift`) clamps even an explicit `Retry-After` or `RateLimit-Reset` to `maxBackoff` (16s). Apple's rate-limit guide says to wait the `Retry-After` seconds, double on consecutive 429s, and cap only the backoff. With a server-requested wait over 16s, asa retries too early and burns its 5 retries. `APIClientTests.retryDelayBounds` locks in the wrong behavior.

**Fix:** honor `Retry-After` / `RateLimit-Reset` as given (with a generous sanity bound such as 5 minutes), and cap only the `pow(2, attempt)` fallback at 16s. Update the test.
